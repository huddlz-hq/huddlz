defmodule Huddlz.Notifications.Senders.GroupMemberRemoved do
  @moduledoc """
  Sender for B3: a user has been removed from a group.

  Sent to the removed user. Transactional — preferences do not apply,
  no unsubscribe footer.

  Required payload keys:

    * `"group_name"` — display name of the group at the time of removal.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_group = HtmlEscape.escape(group_name(payload))
    groups_url = url(~p"/groups")

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("You were removed from #{group_name(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>You have been removed from the group <strong>#{safe_group}</strong>
    on huddlz. You no longer have access to its member-only content.</p>

    <p>If you think this was a mistake, reach out to the group's owner
    directly. You can browse other groups at
    <a href="#{groups_url}">#{groups_url}</a>.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    You have been removed from the group "#{group_name(payload)}" on huddlz.
    You no longer have access to its member-only content.

    If you think this was a mistake, reach out to the group's owner directly.
    Browse other groups at #{groups_url}.
    """)
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(%{group_name: name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
