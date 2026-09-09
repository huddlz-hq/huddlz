defmodule Huddlz.Notifications.Senders.HuddlCancelled do
  @moduledoc """
  Sender for C3: a huddl the recipient RSVP'd to was cancelled.

  Sent to every RSVP'd user except the actor. Transactional — a
  cancellation of plans the person made is not something to switch off,
  so there is no unsubscribe link.

  Required payload keys:

    * `"huddl_title"`, `"starts_at_iso"`, `"group_name"`, `"group_slug"`.

  Optional: `"cancellation_reason"`, `"time_zone"`, `"physical_location"`.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "Cancelled: #{huddl_title(payload)}",
      kicker: "Cancelled",
      title: Layout.sentence_case("#{huddl_title(payload)} has been cancelled"),
      paragraphs:
        [
          [
            "Hi #{user.display_name}, ",
            {:strong, huddl_title(payload)},
            " with ",
            {:strong, group_name(payload)},
            " has been cancelled. It was scheduled for the time below."
          ]
        ] ++
          reason_paragraphs(payload) ++
          ["If you'd made plans around this, you'll want to know. Sorry for the disruption."],
      facts: Layout.huddl_facts(payload),
      action: {"Browse other huddlz", Urls.group_url(payload)},
      footer: Footer.account("You're receiving this email because you had RSVP'd to this huddl.")
    })
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "a huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"

  defp reason_paragraphs(%{"cancellation_reason" => reason})
       when is_binary(reason) and reason != "" do
    [["The organizer shared: ", {:strong, reason}]]
  end

  defp reason_paragraphs(_payload), do: []
end
