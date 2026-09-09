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

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "You're now a member of #{group_name(payload)}",
      kicker: "Welcome",
      title: "You're now a member of #{group_name(payload)}",
      paragraphs: [
        [
          "Hi #{user.display_name}, you've been added to ",
          {:strong, group_name(payload)},
          " on huddlz. Visit the group page to see upcoming huddlz and say hello."
        ]
      ],
      action: {"Open the group", Urls.group_url(payload)},
      footer: Footer.activity(user, :group_member_added)
    })
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
