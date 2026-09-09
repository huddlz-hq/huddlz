defmodule Huddlz.Notifications.Senders.GroupOwnershipTransferred do
  @moduledoc """
  Sender for B7: ownership of a group moved. Two audiences, both
  transactional: the previous owner (`role: "previous_owner"`, the
  default) and the new owner (`role: "new_owner"`).

  Payload keys: `"group_name"`, `"group_slug"`, `"role"`,
  `"new_owner_display_name"`, `"previous_owner_display_name"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    case payload["role"] || "previous_owner" do
      "new_owner" -> build_new_owner(user, payload)
      _ -> build_previous_owner(user, payload)
    end
  end

  defp build_previous_owner(user, payload) do
    new_owner = payload["new_owner_display_name"] || "another member"

    Layout.email(%{
      to: user.email,
      subject: "You transferred #{group_name(payload)} to a new owner",
      kicker: "Ownership",
      title: "#{group_name(payload)} has a new owner",
      paragraphs: [
        [
          "Hi #{user.display_name}, you've transferred ownership of ",
          {:strong, group_name(payload)},
          " to ",
          {:strong, new_owner},
          ". You're still part of the group as an organizer and can step away or rejoin anytime."
        ]
      ],
      action: {"Open the group", Urls.group_url(payload)},
      footer: Footer.account("You're receiving this email because you owned this group.")
    })
  end

  defp build_new_owner(user, payload) do
    previous_owner = payload["previous_owner_display_name"] || "The previous owner"

    Layout.email(%{
      to: user.email,
      subject: "You're the new owner of #{group_name(payload)}",
      kicker: "Ownership",
      title: "You're the new owner of #{group_name(payload)}",
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, previous_owner},
          " has transferred ownership of ",
          {:strong, group_name(payload)},
          " to you. The group is now yours to manage."
        ],
        "Open the group page to review members, organizers, and upcoming huddlz."
      ],
      action: {"Open the group", Urls.group_url(payload)},
      footer: Footer.account("You're receiving this email because you now own this group.")
    })
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "the group"
end
