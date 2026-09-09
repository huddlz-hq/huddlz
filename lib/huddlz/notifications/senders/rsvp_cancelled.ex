defmodule Huddlz.Notifications.Senders.RsvpCancelled do
  @moduledoc """
  Sender for E2: someone cancelled their RSVP to a huddl the recipient
  organizes.

  Activity category — preferences and the unsubscribe footer apply.

  Payload keys: `"huddl_id"`, `"huddl_title"`, `"group_name"`,
  `"group_slug"`, `"rsvper_display_name"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "#{rsvper_display_name(payload)} cancelled their RSVP to #{huddl_title(payload)}",
      kicker: "RSVP cancelled · #{group_name(payload)}",
      title: "#{rsvper_display_name(payload)} can't make #{huddl_title(payload)}",
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, rsvper_display_name(payload)},
          " cancelled their RSVP to ",
          {:strong, huddl_title(payload)},
          " with ",
          {:strong, group_name(payload)},
          "."
        ]
      ],
      action: {"See who's coming", Urls.huddl_url(payload)},
      footer: Footer.activity(user, :rsvp_cancelled)
    })
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "your huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "your group"

  defp rsvper_display_name(%{"rsvper_display_name" => name}) when is_binary(name), do: name
  defp rsvper_display_name(_), do: "Someone"
end
