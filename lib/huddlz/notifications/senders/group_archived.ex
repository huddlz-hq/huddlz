defmodule Huddlz.Notifications.Senders.GroupArchived do
  @moduledoc """
  Sender for B6: a group the recipient belongs to was archived, or
  deleted outright. Transactional.

  An archive carries `"archived_at"` and `"group_slug"`; the group's
  history stays reachable. A deletion carries neither.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, %{"archived_at" => _, "group_slug" => slug} = payload) do
    Layout.email(%{
      to: user.email,
      subject: "#{group_name(payload)} has been archived",
      kicker: "Archived",
      title: Layout.sentence_case("#{group_name(payload)} has been archived"),
      paragraphs: [
        [
          "Hi #{user.display_name}, the group ",
          {:strong, group_name(payload)},
          " has been archived on huddlz."
        ],
        "New activity is closed. Your membership and the group's history are preserved, and the owner can restore the group later."
      ],
      action: {"View group history", url(~p"/groups/#{slug}")},
      footer:
        Footer.account("You're receiving this email because you are a member of this group.")
    })
  end

  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "#{group_name(payload)} has been deleted",
      kicker: "Deleted",
      title: Layout.sentence_case("#{group_name(payload)} has been deleted"),
      paragraphs: [
        [
          "Hi #{user.display_name}, the group ",
          {:strong, group_name(payload)},
          " has been deleted on huddlz. You no longer have access to its huddlz or member-only content."
        ]
      ],
      action: {"Browse other groups", url(~p"/discover?#{[scope: "groups"]}")},
      footer:
        Footer.account("You're receiving this email because you were a member of this group.")
    })
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
