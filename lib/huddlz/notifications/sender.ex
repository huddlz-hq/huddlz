defmodule Huddlz.Notifications.Sender do
  @moduledoc """
  Behaviour every notification email sender implements.

  Senders are pure builders. They receive a user and a payload, and return a
  `Swoosh.Email`. They do not decide whether to send (the orchestrator does)
  and they do not call the mailer (the orchestrator does). This keeps senders
  trivially testable: assert the email looks right, no mocks needed.

  See `Huddlz.Notifications` for the orchestrator and `Huddlz.Notifications.Triggers`
  for the registry that maps trigger atoms to their sender modules.
  """

  alias Huddlz.Accounts.User

  @callback build(user :: User.t(), payload :: map()) :: Swoosh.Email.t()
end
