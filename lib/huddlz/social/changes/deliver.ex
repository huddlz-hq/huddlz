defmodule Huddlz.Social.Changes.Deliver do
  @moduledoc """
  Sends a scheduled social post through its connection and records the
  result. A post its connection can no longer make (paused, needing
  reconnecting), about a huddl that can no longer be posted, or picked up
  long after its moment is skipped: posts are never sent late.

  A platform that refuses the post outright marks the post not sent and the
  connection as needing reconnecting, and the group owner is emailed once.
  Any other failure fails the action so the job retries; the trigger
  records the post as not sent once the retries run out, without an email.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.{Huddl, SocialConnection}
  alias Huddlz.Communities.SocialConnection.Kind
  alias Huddlz.Notifications
  alias Huddlz.Social
  alias Huddlz.Social.{Post, Schedule}

  # How late a post may still go out, for a queue that falls behind.
  @grace_seconds 15 * 60

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &deliver/1)
  end

  defp deliver(%{data: %{state: :scheduled} = post} = changeset) do
    now = DateTime.utc_now()

    if DateTime.after?(post.due_at, now),
      do: changeset,
      else: deliver_due(changeset, post, now)
  end

  defp deliver(changeset), do: changeset

  defp deliver_due(changeset, post, now) do
    connection = lock_connection(post.social_connection_id)
    huddl = load_huddl(post.huddl_id)

    if sendable?(post, connection, huddl, now) do
      send_post(changeset, post, connection, huddl, now)
    else
      Ash.Changeset.force_change_attribute(changeset, :state, :skipped)
    end
  end

  defp sendable?(post, connection, huddl, now) do
    connection.state == :posting and huddl != nil and
      DateTime.diff(now, post.due_at) <= @grace_seconds and
      huddl_sendable?(post.occasion, huddl, now)
  end

  defp huddl_sendable?(_occasion, %{is_private: true}, _now), do: false
  defp huddl_sendable?(_occasion, %{group: %{is_public: false}}, _now), do: false
  defp huddl_sendable?(:cancelled, huddl, _now), do: huddl.lifecycle_state == :cancelled
  defp huddl_sendable?(:moved, huddl, _now), do: Schedule.postable?(huddl)

  defp huddl_sendable?(_occasion, huddl, now),
    do: Schedule.postable?(huddl) and DateTime.after?(huddl.starts_at, now)

  defp send_post(changeset, post, connection, huddl, now) do
    case Social.post(connection, text(post, connection, huddl)) do
      :ok ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :sent)
        |> Ash.Changeset.force_change_attribute(:sent_at, now)

      {:error, :revoked} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :not_sent)
        |> Ash.Changeset.after_action(fn _changeset, post ->
          :ok = stop(connection, huddl)
          {:ok, post}
        end)

      {:error, reason} ->
        Ash.Changeset.add_error(
          changeset,
          "The social post didn't go through: #{inspect(reason)}"
        )
    end
  end

  # The connection stops posting and its owner hears about it, once: only
  # a connection that was posting is moved, so later refusals stay quiet.
  defp stop(connection, huddl) do
    stopped =
      Communities.mark_social_connection_needs_reconnecting!(connection, authorize?: false)

    if connection.state == :posting and stopped.state == :needs_reconnecting do
      owner = Ash.get!(Huddlz.Accounts.User, huddl.group.owner_id, authorize?: false)

      {:ok, _job} =
        Notifications.deliver(owner, :social_connection_stopped, %{
          "group_name" => to_string(huddl.group.name),
          "group_slug" => to_string(huddl.group.slug),
          "channel_name" => connection.channel_name,
          "platform" => Kind.label(connection.kind),
          "huddl_title" => huddl.title
        })
    end

    :ok
  end

  defp text(post, connection, huddl) do
    Post.text(huddl,
      moment: post.occasion,
      opening_line: connection.opening_line,
      link: Social.huddl_link(huddl),
      series: huddl.huddl_template,
      previous_starts_at: post.previous_starts_at,
      previous_time_zone: post.previous_time_zone
    )
  end

  # Posts through one connection go one at a time, so a refusal is seen by
  # the next post and the owner is emailed once.
  defp lock_connection(id) do
    SocialConnection
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one!(authorize?: false)
  end

  defp load_huddl(id) do
    Huddl
    |> Ash.Query.for_read(:get_for_mutation, %{id: id})
    |> Ash.Query.load([:group, :huddl_template, :rsvp_count, :waitlist_count])
    |> Ash.read_one!(authorize?: false)
  end
end
