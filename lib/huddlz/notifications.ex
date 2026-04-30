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
  alias HuddlzWeb.Endpoint

  @unsubscribe_salt "notifications:unsubscribe"
  # 30 days — long enough for an email to sit in an inbox over a vacation.
  @unsubscribe_max_age 60 * 60 * 24 * 30

  @type deliver_result :: :sent | :skipped | {:error, term()}

  @doc """
  Build and deliver the email for `trigger` to `user`.

  Returns `:sent` if the mailer accepted the email, `:skipped` if the user is
  not eligible (preferences off, unconfirmed, etc.), or `{:error, reason}` if
  the mailer rejected.

  Raises if `trigger` is not in the registry — callers should use known atoms.
  """
  @spec deliver(User.t(), atom(), map()) :: deliver_result()
  def deliver(user, trigger, payload \\ %{}) do
    entry = Triggers.fetch!(trigger)

    if should_deliver?(user, trigger, entry) do
      ensure_sender_implemented!(trigger, entry.sender)
      email = entry.sender.build(user, payload)

      case Mailer.deliver(email) do
        {:ok, _result} -> :sent
        {:error, reason} -> {:error, reason}
      end
    else
      :skipped
    end
  end

  # The registry references sender modules for triggers whose phases haven't
  # shipped yet. Raise a clear error rather than the cryptic
  # UndefinedFunctionError you'd get from a missing module/function.
  defp ensure_sender_implemented!(trigger, sender) do
    Code.ensure_loaded(sender)

    unless function_exported?(sender, :build, 2) do
      raise ArgumentError,
            "Notification sender #{inspect(sender)} for trigger #{inspect(trigger)} " <>
              "is not yet implemented. Implement Huddlz.Notifications.Sender.build/2 in that module."
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

  @doc """
  Build a signed token for the unsubscribe confirmation flow. Token is bound
  to the user id and trigger so it cannot be reused for another user or
  another category.
  """
  @spec unsubscribe_token(User.t(), atom()) :: String.t()
  def unsubscribe_token(%User{id: user_id}, trigger) when is_atom(trigger) do
    Phoenix.Token.sign(Endpoint, @unsubscribe_salt, {user_id, trigger})
  end

  @doc """
  Verify an unsubscribe token. Returns `{:ok, {user_id, trigger}}` if the
  token is valid and not expired. Otherwise `{:error, reason}`.
  """
  @spec verify_unsubscribe_token(String.t()) ::
          {:ok, {Ecto.UUID.t(), atom()}} | {:error, atom()}
  def verify_unsubscribe_token(token) when is_binary(token) do
    Phoenix.Token.verify(Endpoint, @unsubscribe_salt, token, max_age: @unsubscribe_max_age)
  end
end
