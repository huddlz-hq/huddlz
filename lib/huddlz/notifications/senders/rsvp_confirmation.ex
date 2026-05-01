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
  import Swoosh.Email

  alias Huddlz.Communities.Huddl
  alias Huddlz.Mailer
  alias Huddlz.Notifications.DateTimeFormatter
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    huddl = fetch_huddl!(payload)

    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl.title)
    safe_group = HtmlEscape.escape(huddl.group.name)

    when_text =
      DateTimeFormatter.format_starts_at(
        huddl.starts_at,
        DateTimeFormatter.time_zone_from_payload(payload)
      )

    safe_when = HtmlEscape.escape(when_text)
    huddl_url = url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")

    {footer_html, footer_text} = Footer.build(user, :rsvp_confirmation)
    {ics_filename, ics_content} = ICS.event_for(huddl)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("You're going to #{huddl.title}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>You're confirmed for <strong>#{safe_title}</strong> in
    <strong>#{safe_group}</strong> on #{safe_when}.</p>

    <p>The calendar event is attached. Or open the huddl page at
    <a href="#{huddl_url}">#{huddl_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    You're confirmed for "#{huddl.title}" in "#{huddl.group.name}" on #{when_text}.

    The calendar event is attached. Or open the huddl page at #{huddl_url}.
    #{footer_text}
    """)
    |> attachment(
      Swoosh.Attachment.new({:data, ics_content},
        filename: ics_filename,
        content_type: "text/calendar"
      )
    )
  end

  defp fetch_huddl!(%{"huddl_id" => id}) when is_binary(id) do
    Ash.get!(Huddl, id, authorize?: false, load: [:group])
  end

  defp fetch_huddl!(_) do
    raise ArgumentError, "RsvpConfirmation requires payload key \"huddl_id\" with a binary UUID"
  end
end
