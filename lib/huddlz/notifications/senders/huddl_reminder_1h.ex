defmodule Huddlz.Notifications.Senders.HuddlReminder1h do
  @moduledoc """
  Sender for D2: 1-hour reminder for an imminent huddl.

  Sent to every user who has RSVP'd at fire time. Activity category —
  preferences and the unsubscribe footer apply.

  Leads with the virtual link when one is set so the recipient can
  click straight through to the call rather than hunting for it.

  Required payload keys:

    * `"huddl_id"` — see HuddlReminder24h for the rationale.
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
    huddl_url = url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")

    {footer_html, footer_text} = Footer.build(user, :huddl_reminder_1h)
    {ics_filename, ics_content} = ICS.event_for(huddl)

    {html_call, text_call} = call_lines(huddl)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("Starting soon: #{huddl.title}")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p><strong>#{safe_title}</strong> in <strong>#{safe_group}</strong>
    starts in about an hour.</p>
    #{html_call}
    <p>Or open the huddl page at <a href="#{huddl_url}">#{huddl_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    "#{huddl.title}" in "#{huddl.group.name}" starts in about an hour.
    #{text_call}
    Or open the huddl page at #{huddl_url}.
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

  defp call_lines(%Huddl{virtual_link: link}) when is_binary(link) and link != "" do
    safe_link = HtmlEscape.escape(link)

    html = """
    <p><strong>Join the call:</strong>
    <a href="#{safe_link}">#{safe_link}</a></p>
    """

    text = "Join the call: #{link}\n"
    {html, text}
  end

  defp call_lines(_), do: {"", ""}
end
