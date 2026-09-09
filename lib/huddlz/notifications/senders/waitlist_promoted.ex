defmodule Huddlz.Notifications.Senders.WaitlistPromoted do
  @moduledoc """
  Sender for E4: a waitlisted user was promoted to attendee.

  Transactional — the person asked to attend and now can, so no
  preference applies and there is no unsubscribe link. Includes the
  `.ics` calendar attachment.

  Required payload keys:

    * `"huddl_id"` — UUID of the huddl. The sender re-reads the row to
      build the body and attach the live `.ics`.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email, only: [attachment: 2]

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.HuddlAccess
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, payload) do
    huddl = fetch_huddl!(payload, user)
    huddl_url = url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")
    {ics_filename, ics_content} = ICS.event_for(huddl)

    Layout.email(%{
      to: user.email,
      subject: "You're in: #{huddl.title}",
      kicker: "Off the waitlist",
      title: "You're in: #{huddl.title}",
      paragraphs: [
        [
          "Hi #{user.display_name}, a spot opened up in ",
          {:strong, huddl.title},
          " with ",
          {:strong, huddl.group.name},
          " and you've been promoted from the waitlist. You're now confirmed as an attendee."
        ]
      ],
      facts: Layout.huddl_facts(huddl),
      action: {"Open the huddl", huddl_url},
      aside:
        "The calendar event is attached. Open the huddl page if you need to back out so the spot can go to someone else.",
      footer:
        Footer.account(
          "You're receiving this email because you joined the waitlist for this huddl."
        )
    })
    |> attachment(
      Swoosh.Attachment.new({:data, ics_content},
        filename: ics_filename,
        content_type: "text/calendar"
      )
    )
  end

  defp fetch_huddl!(%{"huddl_id" => id}, user) when is_binary(id) do
    HuddlAccess.for_recipient!(id, user)
  end

  defp fetch_huddl!(_, _user) do
    raise ArgumentError, "WaitlistPromoted requires payload key \"huddl_id\" with a binary UUID"
  end
end
