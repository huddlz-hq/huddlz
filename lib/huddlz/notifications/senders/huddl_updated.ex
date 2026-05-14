defmodule Huddlz.Notifications.Senders.HuddlUpdated do
  @moduledoc """
  Sender for C2: a meaningful field on a huddl was changed (`title`,
  `starts_at`, `ends_at`, `physical_location`, or `virtual_link`).

  Sent to every user who has currently RSVP'd, excluding the actor.
  Activity category — preferences and the unsubscribe footer apply.

  Required payload keys:

    * `"huddl_id"`, `"huddl_title"`, `"starts_at_iso"`,
      `"group_name"`, `"group_slug"` — same as C1.
    * `"changed_fields"` — list of attribute strings that were
      modified, used to render a "what changed" line in the body.
  """

  @behaviour Huddlz.Notifications.Sender

  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.DateTimeFormatter
  alias Huddlz.Notifications.Footer
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
    huddl_url = Urls.huddl_url(payload)

    {footer_html, footer_text} = Footer.build(user, :huddl_updated)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("Updated: #{huddl_title(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>The huddl <strong>#{safe_title}</strong> in
    <strong>#{safe_group}</strong> has been updated.</p>

    <p><strong>What changed:</strong> #{safe_changed}.</p>

    <p>It is currently scheduled for #{safe_when}. See the latest
    details at <a href="#{huddl_url}">#{huddl_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    The huddl "#{huddl_title(payload)}" in "#{group_name(payload)}" has been updated.

    What changed: #{ChangedFields.summary(payload)}.

    It is currently scheduled for #{when_text}. See the latest details at
    #{huddl_url}.
    #{footer_text}
    """)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "a huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
