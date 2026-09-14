defmodule Huddlz.Accounts.SuspensionEvents do
  @moduledoc """
  Tells the pages a person has open that their account was suspended, so
  they sign out on the spot instead of on their next navigation. Runs once
  the suspension has committed.
  """

  @pubsub Huddlz.PubSub

  @behaviour Ash.Notifier

  @impl true
  def requires_original_data?(_resource, _action), do: false

  @impl true
  def notify(%Ash.Notifier.Notification{action: %{name: :suspend}, data: %{id: user_id}}) do
    Phoenix.PubSub.broadcast(@pubsub, topic(user_id), {:account_suspended, user_id})
  end

  def notify(_notification), do: :ok

  def subscribe(user_id) when is_binary(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  defp topic(user_id), do: "user_suspension:#{user_id}"
end
