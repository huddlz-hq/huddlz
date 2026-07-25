defmodule Huddlz.Communities.MembershipEvents do
  @moduledoc """
  Publishes group membership changes to mounted LiveViews.

  Domain actions remain the source of truth. Messages only prompt connected
  views to re-read membership-dependent state through authorized actions.
  """

  @pubsub Huddlz.PubSub

  def subscribe(group_id) when is_binary(group_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(group_id))
  end

  def broadcast(group_id) when is_binary(group_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(group_id), {:group_membership_changed, group_id})
  end

  defp topic(group_id), do: "group-membership:#{group_id}"
end
