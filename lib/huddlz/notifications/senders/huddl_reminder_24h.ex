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
  import Swoosh.Email

  alias Huddlz.Communities.Huddl
  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    huddl = fetch_huddl!(payload)

    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl.title)
    safe_group = HtmlEscape.escape(huddl.group.name)
    when_text = format_starts_at(huddl.starts_at)
    safe_when = HtmlEscape.escape(when_text)
    huddl_url = url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")

    {footer_html, footer_text} = Footer.build(user, :huddl_reminder_24h)
    {ics_filename, ics_content} = ICS.event_for(huddl)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("Tomorrow: #{huddl.title}")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>This is a reminder that <strong>#{safe_title}</strong> in
    <strong>#{safe_group}</strong> starts in about 24 hours
    (#{safe_when}).</p>

    <p>The calendar event is attached. Or open the huddl page at
    <a href="#{huddl_url}">#{huddl_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    This is a reminder that "#{huddl.title}" in "#{huddl.group.name}" starts in
    about 24 hours (#{when_text}).

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

  defp format_starts_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%a %b %-d, %Y at %-I:%M %p UTC")
  end
end
