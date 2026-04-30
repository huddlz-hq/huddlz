defmodule Huddlz.Notifications.DeliverWorker do
  @moduledoc """
  Oban worker that delivers a single notification email asynchronously.

  Args (string-keyed because they round-trip through Oban's JSONB columns):

      %{"user_id" => "...", "trigger" => "password_changed", "payload" => %{}}

  Looks up the user, then calls `Huddlz.Notifications.deliver/3` — the same
  synchronous code path that direct callers use. Eligibility, preferences,
  and sender dispatch live there; the worker is just the async wrapper.

  Delivery failures retry with the worker's default exponential backoff.
  Skipped or unknown-user jobs return `{:cancel, reason}` so they don't
  retry.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 5

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  @impl true
  def perform(%Oban.Job{args: args}) do
    with {:ok, user_id} <- fetch_arg(args, "user_id"),
         {:ok, trigger} <- fetch_trigger(args),
         {:ok, user} <- fetch_user(user_id) do
      payload = Map.get(args, "payload", %{})

      case Notifications.deliver(user, trigger, payload) do
        :sent -> :ok
        :skipped -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp fetch_arg(args, key) do
    case Map.fetch(args, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:cancel, "missing required arg: #{key}"}
    end
  end

  defp fetch_trigger(args) do
    with {:ok, trigger_str} <- fetch_arg(args, "trigger") do
      {:ok, String.to_existing_atom(trigger_str)}
    end
  rescue
    ArgumentError -> {:cancel, "unknown trigger"}
  end

  defp fetch_user(user_id) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, user} -> {:ok, user}
      {:error, _} -> {:cancel, "user #{user_id} not found"}
    end
  end
end
