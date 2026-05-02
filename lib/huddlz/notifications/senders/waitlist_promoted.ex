defmodule Huddlz.Notifications.Senders.WaitlistPromoted do
  @moduledoc """
  Sender for the waitlist promotion email: a user was moved off the
  waitlist into an active RSVP, either because someone cancelled or
  because the organizer raised the capacity.

  Transactional — the recipient may have shelved their plans assuming
  they wouldn't get in. Includes an `.ics` calendar attachment so they
  can save the huddl to their calendar.

  Required payload keys:

    * `"huddl_id"` — UUID of the huddl. The sender re-reads the row to
      construct the email body and attach the live `.ics`.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Communities.Huddl
  alias Huddlz.Mailer
  alias Huddlz.Notifications.DateTimeFormatter
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

    {ics_filename, ics_content} = ICS.event_for(huddl)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("You're in: #{huddl.title}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>A spot opened up in <strong>#{safe_title}</strong>
    (#{safe_group}) on #{safe_when}, and you've been promoted from the
    waitlist. You're now confirmed as an attendee.</p>

    <p>The calendar event is attached. Open the huddl page at
    <a href="#{huddl_url}">#{huddl_url}</a> if you need to back out.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    A spot opened up in "#{huddl.title}" (#{huddl.group.name}) on #{when_text},
    and you've been promoted from the waitlist. You're now confirmed as an attendee.

    The calendar event is attached. Open the huddl page at #{huddl_url} if you need
    to back out.
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
    raise ArgumentError, "WaitlistPromoted requires payload key \"huddl_id\" with a binary UUID"
  end
end
