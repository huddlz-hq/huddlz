defmodule Huddlz.Notifications.Footer do
  @moduledoc """
  The footer every email ends with: why the person is receiving it and,
  for activity emails, the unsubscribe and settings links. Returns the
  footer spec `Huddlz.Notifications.Layout` renders in both bodies.

  Activity emails get `activity/2`, which builds a per-trigger unsubscribe
  URL from `Notifications.unsubscribe_token/2`. Transactional emails get
  `account/1` with a plain reason and no links, since there is no
  preference to switch off.
  """

  use HuddlzWeb, :verified_routes

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  @activity_reason "You're receiving this email because of your huddlz notification settings."
  @account_reason "You're receiving this email because it concerns your huddlz account."

  @spec activity(User.t(), atom()) :: Notifications.Layout.footer()
  def activity(%User{} = user, trigger) when is_atom(trigger) do
    token = Notifications.unsubscribe_token(user, trigger)

    %{
      reason: @activity_reason,
      links: [
        {"Unsubscribe from this kind of email", url(~p"/unsubscribe/#{token}")},
        {"Manage all your preferences", url(~p"/profile/notifications")}
      ]
    }
  end

  @spec account(String.t()) :: Notifications.Layout.footer()
  def account(reason \\ @account_reason) when is_binary(reason) do
    %{reason: reason, links: []}
  end
end
