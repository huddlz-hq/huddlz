defmodule Huddlz.Notifications.Senders.RsvpCancelled do
  @moduledoc """
  Sender for E2: someone cancelled their RSVP to a huddl in a group I
  organize.

  Sent to each owner/organizer of the group (deduplicated, actor
  excluded). Activity category — preferences and the unsubscribe footer
  apply.

  Required payload keys:

    * `"huddl_id"` — used to render the huddl page link.
    * `"huddl_title"` — display name of the huddl.
    * `"group_name"` — display name of the group.
    * `"group_slug"` — slug used in the huddl page URL.
    * `"rsvper_display_name"` — name of the user who cancelled.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl_title(payload))
    safe_group = HtmlEscape.escape(group_name(payload))
    safe_rsvper = HtmlEscape.escape(rsvper_display_name(payload))
    huddl_url = huddl_url(payload)

    {footer_html, footer_text} = Footer.build(user, :rsvp_cancelled)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(
      HeaderSafe.safe(
        "#{rsvper_display_name(payload)} cancelled their RSVP to #{huddl_title(payload)}"
      )
    )
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p><strong>#{safe_rsvper}</strong> cancelled their RSVP to
    <strong>#{safe_title}</strong> in <strong>#{safe_group}</strong>.
    See the current attendee list at <a href="#{huddl_url}">#{huddl_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    #{rsvper_display_name(payload)} cancelled their RSVP to "#{huddl_title(payload)}" in "#{group_name(payload)}".
    See the current attendee list at #{huddl_url}.
    #{footer_text}
    """)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "your huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "your group"

  defp rsvper_display_name(%{"rsvper_display_name" => name}) when is_binary(name), do: name
  defp rsvper_display_name(_), do: "Someone"

  defp huddl_url(%{"group_slug" => slug, "huddl_id" => id})
       when is_binary(slug) and is_binary(id),
       do: url(~p"/groups/#{slug}/huddlz/#{id}")

  defp huddl_url(_), do: url(~p"/")
end
