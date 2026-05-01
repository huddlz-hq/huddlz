defmodule Huddlz.Notifications.Senders.GroupMemberJoined do
  @moduledoc """
  Sender for B1: a user joined a public group.

  Sent to each owner/organizer of the group (deduplicated, actor
  excluded). Activity category — preferences and the unsubscribe footer
  apply.

  Required payload keys:

    * `"group_id"` — used to render the group page link.
    * `"group_name"` — display name of the group.
    * `"group_slug"` — slug used in the group page URL.
    * `"joiner_display_name"` — name of the user who joined.
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
    safe_group = HtmlEscape.escape(group_name(payload))
    safe_joiner = HtmlEscape.escape(joiner_display_name(payload))
    group_url = group_url(payload)

    {footer_html, footer_text} = Footer.build(user, :group_member_joined)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("#{joiner_display_name(payload)} joined #{group_name(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p><strong>#{safe_joiner}</strong> just joined your group
    <strong>#{safe_group}</strong>. Say hi or check out the group page
    at <a href="#{group_url}">#{group_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    #{joiner_display_name(payload)} just joined your group "#{group_name(payload)}".
    Say hi or check out the group page at #{group_url}.
    #{footer_text}
    """)
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "your group"

  defp joiner_display_name(%{"joiner_display_name" => name}) when is_binary(name), do: name
  defp joiner_display_name(_), do: "Someone"

  defp group_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  defp group_url(_), do: url(~p"/groups")
end
