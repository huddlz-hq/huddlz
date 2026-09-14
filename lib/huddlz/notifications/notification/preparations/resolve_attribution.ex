defmodule Huddlz.Notifications.Notification.Preparations.ResolveAttribution do
  @moduledoc "Resolves stored notification attribution before it reaches the inbox."
  use Ash.Resource.Preparation

  alias Huddlz.Notifications.{Attribution, Summary}

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.after_action(query, fn _query, notifications ->
      payloads = Attribution.resolve_many(Enum.map(notifications, & &1.payload))
      {:ok, Enum.zip_with(notifications, payloads, &resolve/2)}
    end)
  end

  defp resolve(%{payload: payload} = notification, payload), do: notification

  defp resolve(notification, payload) do
    summary = Summary.summarize(String.to_existing_atom(notification.trigger), payload)
    notification |> Map.merge(summary) |> Map.put(:payload, payload)
  end
end
