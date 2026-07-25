defmodule Huddlz.Communities.MembershipEvents do
  @moduledoc """
  Prompts connected group surfaces to re-read membership state after commits.

  Ash actions and policies remain the source of truth. PubSub messages carry
  identifiers only and never substitute for an authorized read.
  """

  @pubsub Huddlz.PubSub

  def subscribe(group_id) when is_binary(group_id) do
    Phoenix.PubSub.subscribe(@pubsub, group_topic(group_id))
  end

  def subscribe_user(user_id) when is_binary(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, user_topic(user_id))
  end

  def broadcast(group_id, user_id) when is_binary(group_id) and is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      group_topic(group_id),
      {:group_membership_changed, group_id}
    )

    Phoenix.PubSub.broadcast(
      @pubsub,
      user_topic(user_id),
      {:user_group_membership_changed, user_id, group_id}
    )
  end

  defp group_topic(group_id), do: "group-membership:#{group_id}"
  defp user_topic(user_id), do: "user-group-memberships:#{user_id}"
end
