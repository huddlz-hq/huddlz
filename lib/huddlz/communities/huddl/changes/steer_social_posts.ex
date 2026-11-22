defmodule Huddlz.Communities.Huddl.Changes.SteerSocialPosts do
  @moduledoc """
  Steers one huddl's social posts on one of its group's connections: skip
  it there, post it there again, or post it there now. Only a published
  public huddl of a public group that has not started can be steered.

  Posting now sends before the action returns. The post is put on the
  huddl's metadata (`:social_post`) with its connection
  (`:social_connection`), so the caller can say how it went and the
  activity log can name the place.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities.SocialConnection
  alias Huddlz.Social.Schedule

  @impl true
  def change(changeset, opts, context) do
    id = Ash.Changeset.get_argument(changeset, :social_connection_id)
    huddl = Ash.load!(changeset.data, [:group], authorize?: false)

    with {:ok, connection} <- connection_of(huddl, id),
         :ok <- steerable(huddl),
         :ok <- allowed(opts[:to], huddl, connection) do
      register_steering(changeset, opts[:to], huddl, connection, context.actor)
    else
      {:error, message} ->
        Ash.Changeset.add_error(changeset, field: :social_connection_id, message: message)
    end
  end

  # Delivery has its own transaction: a temporary failure must not roll
  # back the scheduled post that the worker will retry.
  defp register_steering(changeset, :post_now, huddl, connection, actor) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, result} ->
        post =
          case Schedule.post_now(huddl, connection, actor) do
            {:ok, post} -> post
            {:error, _error} -> nil
          end

        {:ok,
         result
         |> with_connection(connection)
         |> Ash.Resource.put_metadata(:social_post, post)}

      _changeset, result ->
        result
    end)
  end

  defp register_steering(changeset, to, huddl, connection, _actor) do
    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      {:ok, steer(to, result, huddl, connection)}
    end)
  end

  defp steer(:skip, result, huddl, connection) do
    :ok = Schedule.skip(huddl, connection)
    with_connection(result, connection)
  end

  defp steer(:unskip, result, huddl, connection) do
    :ok = Schedule.unskip(huddl, connection)
    with_connection(result, connection)
  end

  defp with_connection(result, connection),
    do: Ash.Resource.put_metadata(result, :social_connection, connection)

  defp connection_of(huddl, id) do
    SocialConnection
    |> Ash.Query.filter(id == ^id and group_id == ^huddl.group_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %SocialConnection{} = connection} -> {:ok, connection}
      _other -> {:error, "is not one of this group's social connections"}
    end
  end

  defp steerable(huddl) do
    cond do
      not Schedule.postable?(huddl) ->
        {:error, "only a published public huddl of a public group is posted"}

      not DateTime.after?(huddl.starts_at, DateTime.utc_now()) ->
        {:error, "the huddl has already started"}

      true ->
        :ok
    end
  end

  defp allowed(:post_now, huddl, connection) do
    cond do
      connection.state != :posting -> {:error, "is not posting right now"}
      Schedule.skipped?(huddl, connection) -> {:error, "is skipped for this huddl"}
      true -> :ok
    end
  end

  defp allowed(_steer, _huddl, _connection), do: :ok
end
