defmodule Huddlz.Notifications.Senders.GroupRoleChanged do
  @moduledoc """
  Sender for B5: the recipient's role in a group changed.

  Activity category — preferences and the unsubscribe footer apply.

  Payload keys: `"group_name"`, `"group_slug"`, `"previous_role"`, `"new_role"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    previous = role_label(role_value(payload, "previous_role"))
    new_role = role_label(role_value(payload, "new_role"))

    Layout.email(%{
      to: user.email,
      subject: "Your role in #{group_name(payload)} changed",
      kicker: "Your role",
      title: "You're now #{article(new_role)} #{new_role} of #{group_name(payload)}",
      paragraphs: [
        [
          "Hi #{user.display_name}, your role in ",
          {:strong, group_name(payload)},
          " changed from ",
          {:strong, previous},
          " to ",
          {:strong, new_role},
          "."
        ]
      ],
      action: {"Open the group", Urls.group_url(payload)},
      footer: Footer.activity(user, :group_role_changed)
    })
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "the group"

  defp role_value(payload, key) do
    case Map.get(payload, key) do
      value when is_binary(value) -> value
      value when is_atom(value) and not is_nil(value) -> Atom.to_string(value)
      _ -> ""
    end
  end

  defp role_label(""), do: "member"
  defp role_label(role), do: role

  defp article(word) do
    if String.starts_with?(word, ["a", "e", "i", "o", "u"]), do: "an", else: "a"
  end
end
