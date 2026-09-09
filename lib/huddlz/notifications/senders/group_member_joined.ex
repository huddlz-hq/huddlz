defmodule Huddlz.Notifications.Senders.GroupMemberJoined do
  @moduledoc """
  Sender for B1: someone joined a group the recipient organizes.

  Activity category — preferences and the unsubscribe footer apply.

  Payload keys: `"group_name"`, `"group_slug"`, `"joiner_display_name"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "#{joiner_display_name(payload)} joined #{group_name(payload)}",
      kicker: "New member",
      title: "#{joiner_display_name(payload)} joined #{group_name(payload)}",
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, joiner_display_name(payload)},
          " just joined your group ",
          {:strong, group_name(payload)},
          ". Say hi or check out the group page."
        ]
      ],
      action: {"Open the group", Urls.group_url(payload)},
      footer: Footer.activity(user, :group_member_joined)
    })
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "your group"

  defp joiner_display_name(%{"joiner_display_name" => name}) when is_binary(name), do: name
  defp joiner_display_name(_), do: "Someone"
end
