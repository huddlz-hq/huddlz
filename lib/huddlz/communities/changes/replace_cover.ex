defmodule Huddlz.Communities.Changes.ReplaceCover do
  @moduledoc """
  Applies an eagerly uploaded cover inside the parent update transaction.
  RequireActiveGroup holds the group row lock across selection, assignment
  and retirement, including on edits that only change the cover.
  """
  use Ash.Resource.Change
  require Ash.Query

  alias Ash.Error.Changes.InvalidArgument
  alias Huddlz.Communities.{Group, GroupImage, Huddl, HuddlCoverImage}

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.get_argument(changeset, :pending_image_id) do
      nil ->
        changeset

      image_id ->
        Ash.Changeset.after_action(
          changeset,
          fn cs, parent ->
            opts = [actor: context.actor, context: Map.take(cs.context, [:paper_trail_metadata])]
            replace(parent, image_id, opts)
          end,
          prepend?: true
        )
    end
  end

  defp cover(%Group{id: group_id}), do: {GroupImage, :group_id, group_id, :assign_to_group}

  defp cover(%Huddl{group_id: group_id}),
    do: {HuddlCoverImage, :huddl_id, group_id, :assign_to_huddl}

  defp replace(parent, image_id, opts) do
    {resource, parent_key, group_id, action} = cover(parent)
    actor_id = opts[:actor] && opts[:actor].id

    candidate =
      resource
      |> Ash.Query.filter(id == ^image_id and is_nil(deleted_at))
      |> Ash.Query.filter(uploaded_by_id == ^actor_id and pending_group_id == ^group_id)
      |> Ash.Query.lock("FOR UPDATE")

    case Ash.read_one(candidate, opts) do
      {:ok, %{^parent_key => nil} = image} ->
        with {:ok, _} <- Ash.update(image, %{parent_key => parent.id}, [action: action] ++ opts),
             :ok <- retire_previous(resource, parent_key, parent.id, image_id, opts) do
          {:ok, parent}
        end

      {:ok, %{^parent_key => id}} when id == parent.id ->
        {:ok, parent}

      {:ok, _missing_or_assigned_elsewhere} ->
        unavailable()

      {:error, error} ->
        {:error, error}
    end
  end

  defp retire_previous(resource, parent_key, parent_id, image_id, opts) do
    previous =
      resource
      |> Ash.Query.filter(^[{parent_key, parent_id}])
      |> Ash.Query.filter(is_nil(deleted_at) and id != ^image_id)

    with {:ok, images} <- Ash.read(previous, opts) do
      Enum.reduce_while(images, :ok, fn image, :ok -> retire(image, opts) end)
    end
  end

  defp retire(image, opts) do
    case Ash.update(image, %{}, [action: :soft_delete] ++ opts) do
      {:ok, _} -> {:cont, :ok}
      {:error, error} -> {:halt, {:error, error}}
    end
  end

  defp unavailable do
    {:error,
     InvalidArgument.exception(
       field: :pending_image_id,
       message: "The cover could not be saved. Choose the image again."
     )}
  end
end
