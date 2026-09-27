defmodule Huddlz.Notifications.Senders.SocialConnectionStopped do
  @moduledoc """
  Sender for B9: a social connection's platform refused a post (the app was
  removed, the channel is gone), so the connection needs reconnecting and
  posts nothing until it is. Sent once, to the group owner. Transactional.

  Payload keys: `"group_name"`, `"group_slug"`, `"channel_name"`,
  `"platform"`, `"huddl_title"`.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, payload) do
    channel = payload["channel_name"] || "a connected channel"
    platform = payload["platform"] || "The platform"

    Layout.email(%{
      to: user.email,
      subject: "Posts to #{channel} have stopped",
      kicker: "Needs reconnecting",
      title: "Posts to #{channel} have stopped",
      paragraphs: [
        [
          "Hi #{user.display_name}, huddlz could not post ",
          {:strong, payload["huddl_title"] || "a huddl"},
          " to #{channel} on #{platform} for ",
          {:strong, payload["group_name"] || "your group"},
          ". #{platform} says the connection is no longer allowed, which usually means it was removed on their side."
        ],
        "Nothing else will post there until you reconnect it. Your other social connections are still posting."
      ],
      action: {"Reconnect #{channel}", social_url(payload)},
      footer: Footer.account("You're receiving this email because you own this group.")
    })
  end

  defp social_url(%{"group_slug" => slug}) when is_binary(slug),
    do: url(~p"/organize/#{slug}/social")

  defp social_url(_payload), do: url(~p"/organize")
end
