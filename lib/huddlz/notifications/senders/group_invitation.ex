defmodule Huddlz.Notifications.Senders.GroupInvitation do
  @moduledoc """
  Email for an actionable private-group invitation to a registered user.

  Activity category — preferences and the unsubscribe footer apply.

  Payload keys: `"group_name"`, `"inviter_name"`, `"role"`, `"invitation_id"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias HuddlzWeb.Endpoint

  @impl true
  def build(user, payload) do
    group_name = Map.get(payload, "group_name", "a private group")
    inviter_name = Map.get(payload, "inviter_name", "A group organizer")
    role = Map.get(payload, "role", "member")

    Layout.email(%{
      to: user.email,
      subject: "Invitation to #{group_name}",
      kicker: "Invitation",
      title: "#{inviter_name} invited you to #{group_name}",
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, inviter_name},
          " invited you to join ",
          {:strong, group_name},
          " as #{article(role)} #{role}. It is a private group on huddlz."
        ],
        "Joining is always your choice."
      ],
      action: {"Review invitation", Endpoint.url() <> "/invitations/#{payload["invitation_id"]}"},
      aside: "If you weren't expecting this invitation, you can ignore this email.",
      footer: Footer.activity(user, :group_invitation)
    })
  end

  defp article(word) do
    if String.starts_with?(to_string(word), ["a", "e", "i", "o", "u"]), do: "an", else: "a"
  end
end
