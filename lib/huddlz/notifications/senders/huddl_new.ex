defmodule Huddlz.Notifications.Senders.HuddlNew do
  @moduledoc """
  Sender for C1: a new huddl was scheduled in a group the recipient
  belongs to.

  Sent to every member of the group at the moment of creation,
  excluding the user who created it. Activity category — preferences
  and the unsubscribe footer apply.

  Required payload keys:

    * `"huddl_id"` — UUID, used to link to the huddl page.
    * `"huddl_title"` — display title.
    * `"starts_at_iso"` — ISO-8601 string of when it starts.
    * `"group_name"` — host group's display name.
    * `"group_slug"` — host group's slug, used to build the huddl URL.

  Optional: `"ends_at_iso"`, `"time_zone"`, `"physical_location"` and
  `"event_type"` fill in the facts block.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    group = group_name(payload)

    Layout.email(%{
      to: user.email,
      subject: "New huddl in #{group}: #{huddl_title(payload)}",
      kicker: "New huddl · #{group}",
      title: Layout.sentence_case(huddl_title(payload)),
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, group},
          " just scheduled a new huddl. RSVP if you can make it."
        ]
      ],
      facts: Layout.huddl_facts(payload),
      action: {"See the huddl and RSVP", Urls.huddl_url(payload)},
      footer: Footer.activity(user, :huddl_new)
    })
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "a new huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
