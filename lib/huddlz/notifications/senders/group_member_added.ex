defmodule Huddlz.Notifications.Senders.GroupMemberAdded do
  @moduledoc """
  Sender for B2: a user has been added to a (private) group by an
  owner or organizer.

  Sent to the added user. Activity category — preferences and the
  unsubscribe footer apply.

  Required payload keys:

    * `"group_id"` — used for fallback links.
    * `"group_name"` — display name of the group.
    * `"group_slug"` — slug for the group page URL.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer

  @impl true
  def build(user, payload) do
    safe_name = escape(user.display_name)
    safe_group = escape(group_name(payload))
    group_url = group_url(payload)

    {footer_html, footer_text} = Footer.build(user, :group_member_added)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("You're now a member of #{group_name(payload)}")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>You've been added to the group <strong>#{safe_group}</strong> on
    huddlz. Visit the group page at
    <a href="#{group_url}">#{group_url}</a> to see upcoming huddlz and
    say hello.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    You've been added to the group "#{group_name(payload)}" on huddlz.
    Visit the group page at #{group_url} to see upcoming huddlz and say hello.
    #{footer_text}
    """)
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"

  defp group_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  defp group_url(_), do: url(~p"/groups")

  defp escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
