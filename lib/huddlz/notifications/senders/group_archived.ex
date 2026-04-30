defmodule Huddlz.Notifications.Senders.GroupArchived do
  @moduledoc """
  Sender for B6: a group has been deleted (or archived in the future).

  Sent to every member of the group at the moment of deletion.
  Transactional — preferences do not apply, no unsubscribe footer.

  Required payload keys:

    * `"group_name"` — display name of the group at the time of removal.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_group = HtmlEscape.escape(group_name(payload))
    groups_url = url(~p"/groups")

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("#{group_name(payload)} has been deleted")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>The group <strong>#{safe_group}</strong> has been deleted on
    huddlz. You no longer have access to its huddlz or member-only
    content.</p>

    <p>Browse other groups at <a href="#{groups_url}">#{groups_url}</a>.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    The group "#{group_name(payload)}" has been deleted on huddlz. You no longer
    have access to its huddlz or member-only content.

    Browse other groups at #{groups_url}.
    """)
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
