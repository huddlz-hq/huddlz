defmodule Huddlz.Notifications.Senders.AccountSuspended do
  @moduledoc """
  The one email a suspended person gets: what happened, what still works,
  and the one way to reach a person. Deliberately carries no reason, no
  reports, no reporters and no moderation notes.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, _payload) do
    {_name, support} = Huddlz.Mailer.from()
    date = Calendar.strftime(user.suspended_at || DateTime.utc_now(), "%b %-d, %Y")

    Layout.email(%{
      to: user.email,
      subject: "Your huddlz account has been suspended",
      kicker: "Your account",
      title: "Your huddlz account has been suspended",
      paragraphs: [
        [
          "An administrator suspended the huddlz account for ",
          {:strong, to_string(user.email)},
          " on #{date}. You can't sign in, and your upcoming RSVPs have been released. Your groups and huddlz remain in place."
        ],
        "Public huddlz and groups are still open to browse without signing in.",
        [
          "If you think this is a mistake, write to ",
          {:link, support, "mailto:#{support}"},
          " from this address and a person will look at it."
        ]
      ],
      footer: Footer.account()
    })
  end
end
