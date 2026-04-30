defmodule Huddlz.Notifications do
  @moduledoc """
  Email notifications orchestrator.

  Single entry point for sending a notification email. Resolves the user's
  preferences, decides whether to send, and dispatches to the right sender
  module.

      Huddlz.Notifications.deliver(user, :password_changed, %{...})

  See `docs/notifications.md` for the system spec and `Huddlz.Notifications.Triggers`
  for the registry of trigger codes.
  """

  alias Huddlz.Accounts.User
  alias Huddlz.Mailer
  alias Huddlz.Notifications.Triggers

  @type deliver_result :: :ok | :skipped | {:error, term()}

  @doc """
  Build and deliver the email for `trigger` to `user`.

  Returns `:ok` if the mailer accepted the email, `:skipped` if the user is
  not eligible (preferences off, unconfirmed, etc.), or `{:error, reason}` if
  the mailer rejected.

  Raises if `trigger` is not in the registry — callers should use known atoms.
  """
  @spec deliver(User.t(), atom(), map()) :: :sent | :skipped
  def deliver(user, trigger, payload \\ %{}) do
    entry = Triggers.fetch!(trigger)

    if should_deliver?(user, trigger, entry) do
      email = entry.sender.build(user, payload)
      Mailer.deliver(email)
      :sent
    else
      :skipped
    end
  end

  @doc """
  Pure decision function: should this email be sent?

  Used by `deliver/3` and useful directly in tests for asserting the
  preference matrix without going through the mailer.
  """
  @spec should_deliver?(User.t(), atom(), map()) :: boolean()
  def should_deliver?(user, trigger, entry) do
    user_can_receive?(user, entry.category) and preference_allows?(user, trigger, entry)
  end

  # Transactional security emails (password changed, account removed, etc.)
  # must go through even before email confirmation — otherwise an attacker
  # could mutate accounts in the unconfirmed window with no notice. Activity
  # and digest emails wait until the user has confirmed their address.
  defp user_can_receive?(%User{}, :transactional), do: true
  defp user_can_receive?(%User{confirmed_at: nil}, _category), do: false
  defp user_can_receive?(%User{}, _category), do: true
  defp user_can_receive?(_, _), do: false

  defp preference_allows?(_user, _trigger, %{category: :transactional}), do: true

  defp preference_allows?(user, trigger, %{default: default}) do
    key = Triggers.preference_key(trigger)

    case Map.get(user.notification_preferences || %{}, key) do
      nil -> default
      value when is_boolean(value) -> value
      _ -> default
    end
  end
end
