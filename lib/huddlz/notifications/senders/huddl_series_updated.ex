defmodule Huddlz.Notifications.Senders.HuddlSeriesUpdated do
  @moduledoc """
  Sender for C4: a recurring huddl series was modified (the editor
  chose `edit_type: "all"`).

  Sent once to each person with an RSVP on a retained occurrence. The
  payload points to that person's next upcoming RSVP, so the target remains
  useful and authorized without sending one message per occurrence. Activity
  category — preferences and the unsubscribe footer apply.

  Required payload keys are the same as C2 (`huddl_id`,
  `huddl_title`, `starts_at_iso`, `group_name`, `group_slug`,
  `changed_fields`), but the values describe the next-instance row
  rather than the row that triggered the edit. `calendar_huddlz` contains
  schedule payloads for that recipient's active, future RSVPs. Each gets its
  own attachment with the same UID as its confirmation; waitlisted and cancelled
  huddlz are excluded. Older queued payloads without this key remain valid.
  """

  @behaviour Huddlz.Notifications.Sender

  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.DateTimeFormatter
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Senders.ChangedFields
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl_title(payload))
    safe_group = HtmlEscape.escape(group_name(payload))

    when_text =
      DateTimeFormatter.format_starts_at_iso(
        payload["starts_at_iso"],
        DateTimeFormatter.time_zone_from_payload(payload),
        payload["starts_at_iso"] || "the scheduled time"
      )

    safe_when = HtmlEscape.escape(when_text)
    safe_changed = HtmlEscape.escape(ChangedFields.summary(payload))

    calendar_note =
      if Map.get(payload, "calendar_huddlz", []) == [],
        do: "",
        else:
          "Updated calendar entries for your upcoming RSVPs are attached. Open each attachment to update that date in your calendar."

    huddl_url = Urls.huddl_url(payload)

    {footer_html, footer_text} = Footer.build(user, :huddl_series_updated)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("Recurring series updated: #{huddl_title(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>The recurring huddl series in <strong>#{safe_group}</strong>
    has been updated.</p>

    <p><strong>What changed:</strong> #{safe_changed}.</p>

    <p>Your next upcoming instance, <strong>#{safe_title}</strong>,
    is now scheduled for #{safe_when}. See it at
    <a href="#{huddl_url}">#{huddl_url}</a>.</p>

    <p>#{calendar_note}</p>

    <p>You will still receive the usual reminders for each huddl you are attending.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    The recurring huddl series in "#{group_name(payload)}" has been updated.

    What changed: #{ChangedFields.summary(payload)}.

    Your next upcoming instance, "#{huddl_title(payload)}", is now scheduled for
    #{when_text}. See it at #{huddl_url}.

    #{calendar_note}

    You will still receive the usual reminders for each huddl you are attending.
    #{footer_text}
    """)
    |> attach_calendars(payload)
  end

  defp attach_calendars(email, payload) do
    Enum.reduce(Map.get(payload, "calendar_huddlz", []), email, fn huddl, email ->
      {_filename, content} = ICS.updated_huddl(huddl)

      attachment(
        email,
        Swoosh.Attachment.new({:data, content},
          filename: "huddl-#{huddl["huddl_id"]}.ics",
          content_type: "text/calendar"
        )
      )
    end)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "the next instance"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
