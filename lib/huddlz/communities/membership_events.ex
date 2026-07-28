defmodule Huddlz.Communities.MembershipEvents do
  @moduledoc """
  Publishes group membership changes to mounted LiveViews.

  Domain actions remain the source of truth. The messages only prompt
  connected views to re-read through those authorized actions.
  """

  @pubsub Huddlz.PubSub

  def subscribe(group_id) when is_binary(group_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(group_id))
  end

  def subscribe_to_user(user_id) when is_binary(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, user_topic(user_id))
  end

  def broadcast(group_id, affected_user_ids \\ []) when is_binary(group_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(group_id), {:group_membership_changed, group_id})

    affected_user_ids
    |> List.wrap()
    |> Enum.uniq()
    |> Enum.each(fn user_id ->
      Phoenix.PubSub.broadcast(
        @pubsub,
        user_topic(user_id),
        {:organizer_access_changed, user_id}
      )
    end)
  end

  defp topic(group_id), do: "group-membership:#{group_id}"
  defp user_topic(user_id), do: "user-membership:#{user_id}"
end
