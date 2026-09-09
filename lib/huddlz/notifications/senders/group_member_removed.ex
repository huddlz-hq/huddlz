defmodule Huddlz.Notifications.Senders.GroupMemberRemoved do
  @moduledoc """
  Sender for B4: the recipient was removed from a group. Transactional.

  Payload keys: `"group_name"`.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "You were removed from #{group_name(payload)}",
      kicker: "Membership",
      title: "You were removed from #{group_name(payload)}",
      paragraphs: [
        [
          "Hi #{user.display_name}, you have been removed from ",
          {:strong, group_name(payload)},
          " on huddlz. You no longer have access to its member-only content."
        ],
        "If you think this was a mistake, reach out to the group's owner directly."
      ],
      action: {"Browse other groups", url(~p"/discover?#{[scope: "groups"]}")},
      footer:
        Footer.account("You're receiving this email because you were a member of this group.")
    })
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(%{group_name: name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
