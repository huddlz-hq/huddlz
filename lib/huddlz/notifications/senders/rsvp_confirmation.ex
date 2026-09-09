defmodule Huddlz.Notifications.Senders.RsvpConfirmation do
  @moduledoc """
  Sender for E3: confirmation to a user that their RSVP was recorded.

  Sent to the user themselves at RSVP time. Activity category —
  preferences and the unsubscribe footer apply. Includes an `.ics`
  calendar attachment so the recipient can save the huddl to their
  calendar.

  Required payload keys:

    * `"huddl_id"` — UUID of the huddl. The sender re-reads the row
      to construct the email body and attach the live `.ics`. Same
      pattern as the D1/D2 reminder senders.
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
      subject: "You're going to #{huddl.title}",
      kicker: "You're going",
      title: huddl.title,
      paragraphs: [
        [
          "Hi #{user.display_name}, you're confirmed for ",
          {:strong, huddl.title},
          " with ",
          {:strong, huddl.group.name},
          "."
        ]
      ],
      facts: Layout.huddl_facts(huddl),
      action: {"Open the huddl", huddl_url},
      aside: "The calendar event is attached so you can save it to your calendar.",
      footer: Footer.activity(user, :rsvp_confirmation)
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
    raise ArgumentError, "RsvpConfirmation requires payload key \"huddl_id\" with a binary UUID"
  end
end
