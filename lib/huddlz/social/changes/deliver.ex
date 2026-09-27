defmodule Huddlz.Social.Changes.Deliver do
  @moduledoc """
  Sends a scheduled social post through its connection and records the
  result. A post its connection can no longer make (paused, needing
  reconnecting), about a huddl that can no longer be posted, or picked up
  long after its moment is skipped: posts are never sent late.

  A platform that refuses the post outright marks the post not sent and the
  connection as needing reconnecting. Any other failure fails the action so
  the job retries; the trigger records the post as not sent once the
  retries run out.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.{Huddl, SocialConnection}
  alias Huddlz.Social
  alias Huddlz.Social.{Post, Schedule}

  # How late a post may still go out, for a queue that falls behind.
  @grace_seconds 15 * 60

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &deliver/1)
  end

  defp deliver(%{data: %{state: :scheduled} = post} = changeset) do
    connection = Ash.get!(SocialConnection, post.social_connection_id, authorize?: false)
    huddl = load_huddl(post.huddl_id)
    now = DateTime.utc_now()

    if sendable?(post, connection, huddl, now) do
      send_post(changeset, post, connection, huddl, now)
    else
      Ash.Changeset.force_change_attribute(changeset, :state, :skipped)
    end
  end

  defp deliver(changeset), do: changeset

  defp sendable?(post, connection, huddl, now) do
    connection.state == :posting and huddl != nil and
      DateTime.diff(now, post.due_at) <= @grace_seconds and
      huddl_sendable?(post.occasion, huddl, now)
  end

  defp huddl_sendable?(_occasion, %{is_private: true}, _now), do: false
  defp huddl_sendable?(_occasion, %{group: %{is_public: false}}, _now), do: false
  defp huddl_sendable?(:cancelled, huddl, _now), do: huddl.lifecycle_state == :cancelled

  defp huddl_sendable?(_occasion, huddl, now),
    do: Schedule.postable?(huddl) and DateTime.after?(huddl.starts_at, now)

  defp send_post(changeset, post, connection, huddl, now) do
    case Social.post(connection, text(post, connection, huddl)) do
      :ok ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :sent)
        |> Ash.Changeset.force_change_attribute(:sent_at, now)

      {:error, reason} ->
        Ash.Changeset.add_error(
          changeset,
          "The social post didn't go through: #{inspect(reason)}"
        )
    end
  end

  defp text(post, connection, huddl) do
    Post.text(huddl,
      moment: post.occasion,
      opening_line: connection.opening_line,
      link: Social.huddl_link(huddl),
      series: huddl.huddl_template,
      previous_starts_at: post.previous_starts_at
    )
  end

  defp load_huddl(id) do
    Huddl
    |> Ash.Query.for_read(:get_for_mutation, %{id: id})
    |> Ash.Query.load([:group, :huddl_template, :rsvp_count, :waitlist_count])
    |> Ash.read_one!(authorize?: false)
  end
end
