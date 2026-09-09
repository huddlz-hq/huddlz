defmodule Huddlz.Notifications.Senders.RecurringHuddlGenerationFailed do
  @moduledoc """
  Sender for C5: the recurring dates for a series could not all be
  generated. Sent to the organizer who saved it. Transactional.

  Payload keys: `"huddl_id"`, `"huddl_title"`, `"group_name"`, `"group_slug"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "Recurring dates need attention: #{huddl_title(payload)}",
      kicker: "Needs attention",
      title: "Some recurring dates could not be created",
      paragraphs: [
        [
          "Hi #{user.display_name}, we couldn't generate all recurring dates for ",
          {:strong, huddl_title(payload)},
          " in ",
          {:strong, group_name(payload)},
          "."
        ],
        "The original huddl is still available. Review it, then save the series again to retry."
      ],
      action: {"Review the huddl", Urls.huddl_url(payload)},
      footer: Footer.account("You're receiving this email because you organize this huddl.")
    })
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "your recurring huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "your group"
end
