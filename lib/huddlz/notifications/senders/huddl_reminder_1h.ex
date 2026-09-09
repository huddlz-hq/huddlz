defmodule Huddlz.Notifications.Senders.HuddlReminder1h do
  @moduledoc """
  Sender for D2: 1-hour reminder for an upcoming huddl.

  Sent to every user who has RSVP'd at fire time. Activity category —
  preferences and the unsubscribe footer apply. When the recipient may
  see the virtual link, the button is the call itself.

  Required payload keys:

    * `"huddl_id"` — UUID of the huddl. The sender re-reads the row to
      build the body and attach the live `.ics`.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email, only: [attachment: 2]

  alias Huddlz.Communities.Huddl
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.HuddlAccess
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, payload) do
    huddl = fetch_huddl!(payload, user)
    huddl_url = url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")
    {ics_filename, ics_content} = ICS.event_for(huddl)
    {action, aside} = call_to_action(huddl, huddl_url)

    Layout.email(%{
      to: user.email,
      subject: "Starting soon: #{huddl.title}",
      kicker: "Reminder · in about an hour",
      title: "#{huddl.title} starts soon",
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, huddl.title},
          " with ",
          {:strong, huddl.group.name},
          " starts in about an hour."
        ]
      ],
      facts: Layout.huddl_facts(huddl),
      action: action,
      aside: aside,
      footer: Footer.activity(user, :huddl_reminder_1h)
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

  defp call_to_action(%Huddl{virtual_link: link}, huddl_url)
       when is_binary(link) and link != "" do
    {{"Join the call", link}, ["Or open the huddl page: ", {:link, huddl_url, huddl_url}]}
  end

  defp call_to_action(_huddl, huddl_url) do
    {{"Open the huddl", huddl_url}, "The calendar event is attached."}
  end
end
