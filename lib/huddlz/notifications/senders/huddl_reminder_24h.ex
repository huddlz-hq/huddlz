defmodule Huddlz.Notifications.Senders.HuddlReminder24h do
  @moduledoc """
  Sender for D1: 24-hour reminder for an upcoming huddl.

  Sent to every user who has RSVP'd at fire time (resolved by the
  scheduler, not at huddl creation time). Activity category —
  preferences and the unsubscribe footer apply.

  Required payload keys:

    * `"huddl_id"` — UUID of the huddl. The sender re-reads the row
      to construct the email body and attach the live `.ics`. This
      is the documented exception to the "stateless sender" rule;
      the alternative (embedding the binary `.ics` in the JSONB
      payload) is awkward and the row read is cheap relative to
      `Mailer.deliver`.
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
      subject: "Tomorrow: #{huddl.title}",
      kicker: "Reminder · tomorrow",
      title: "#{huddl.title} starts tomorrow",
      paragraphs: [
        [
          "Hi #{user.display_name}, you're going to ",
          {:strong, huddl.title},
          " with ",
          {:strong, huddl.group.name},
          " in about 24 hours. Here is what you need."
        ]
      ],
      facts: Layout.huddl_facts(huddl),
      action: {"Open the huddl", huddl_url},
      aside: "The calendar event is attached, in case it is not on your calendar yet.",
      footer: Footer.activity(user, :huddl_reminder_24h)
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
end
