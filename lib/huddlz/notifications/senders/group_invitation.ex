defmodule Huddlz.Notifications.Senders.GroupInvitation do
  @moduledoc """
  Email for an actionable private-group invitation.
  """

  @behaviour Huddlz.Notifications.Sender

  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape
  alias HuddlzWeb.Endpoint

  @impl true
  def build(user, payload) do
    group_name = Map.get(payload, "group_name", "a private group")
    inviter_name = Map.get(payload, "inviter_name", "A group organizer")
    role = Map.get(payload, "role", "member")
    invitation_url = url("/invitations/#{payload["invitation_id"]}")
    safe_invitation_url = HtmlEscape.escape(invitation_url)
    {footer_html, footer_text} = Footer.build(user, :group_invitation)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("Invitation to #{group_name}"))
    |> html_body("""
    <p>Hi #{HtmlEscape.escape(user.display_name)},</p>

    <p>#{HtmlEscape.escape(inviter_name)} invited you to join
    <strong>#{HtmlEscape.escape(group_name)}</strong> as a
    #{HtmlEscape.escape(role)}.</p>

    <p><a href="#{safe_invitation_url}">Review invitation</a></p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    #{inviter_name} invited you to join "#{group_name}" as a #{role}.
    Review the invitation: #{invitation_url}
    #{footer_text}
    """)
  end

  defp url(path), do: Endpoint.url() <> path
end
