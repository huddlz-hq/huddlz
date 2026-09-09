defmodule Huddlz.Notifications.Senders.AccountRoleChanged do
  @moduledoc """
  Sender for A3: an administrator changed the recipient's account role.

  Activity category — preferences and the unsubscribe footer apply.

  Payload keys: `"new_role"`, `"previous_role"` (optional).
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, payload) do
    new_role = payload["new_role"] || to_string(user.role)
    previous_role = payload["previous_role"]

    Layout.email(%{
      to: user.email,
      subject: "Your huddlz account role was updated",
      kicker: "Your account",
      title: "Your account role is now #{new_role}",
      paragraphs: [
        [
          "Hi #{user.display_name}, an administrator just updated your huddlz account role "
          | change_phrase(previous_role, new_role)
        ],
        "If this looks wrong, reply to this email and we'll sort it out."
      ],
      footer: Footer.activity(user, :account_role_changed)
    })
  end

  defp change_phrase(nil, new_role), do: ["to ", {:strong, new_role}, "."]

  defp change_phrase(previous_role, new_role),
    do: ["from ", {:strong, previous_role}, " to ", {:strong, new_role}, "."]
end
