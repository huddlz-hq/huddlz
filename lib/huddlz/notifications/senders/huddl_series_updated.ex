defmodule Huddlz.Notifications.Senders.HuddlSeriesUpdated do
  @moduledoc """
  Sender for C4: a recurring series the recipient attends was updated.

  Activity category — preferences and the unsubscribe footer apply.
  Updated `.ics` files for the recipient's upcoming RSVPs are attached
  when the payload lists them.

  Required payload keys:

    * `"huddl_id"`, `"huddl_title"`, `"starts_at_iso"`, `"group_name"`,
      `"group_slug"`, `"changed_fields"`.

  Optional: `"calendar_huddlz"` — the instances to attach.
  """

  @behaviour Huddlz.Notifications.Sender

  import Swoosh.Email, only: [attachment: 2]

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.ChangedFields
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    Layout.email(%{
      to: user.email,
      subject: "Recurring series updated: #{huddl_title(payload)}",
      kicker: "Series updated · #{group_name(payload)}",
      title: "The #{huddl_title(payload)} series has been updated",
      paragraphs: [
        [
          "Hi #{user.display_name}, the recurring huddl series in ",
          {:strong, group_name(payload)},
          " has been updated."
        ],
        ["What changed: ", {:strong, ChangedFields.summary(payload)}, "."],
        [
          "Your next upcoming instance, ",
          {:strong, huddl_title(payload)},
          ", is now scheduled as below."
        ]
      ],
      facts: Layout.huddl_facts(payload),
      action: {"See the next huddl", Urls.huddl_url(payload)},
      aside: calendar_aside(payload),
      footer: Footer.activity(user, :huddl_series_updated)
    })
    |> attach_calendars(payload)
  end

  defp calendar_aside(payload) do
    base = "You will still receive the usual reminders for each huddl you are attending."

    if Map.get(payload, "calendar_huddlz", []) == [],
      do: base,
      else:
        "Updated calendar entries for your upcoming RSVPs are attached; open each one to update that date in your calendar. " <>
          base
  end

  defp attach_calendars(email, payload) do
    Enum.reduce(Map.get(payload, "calendar_huddlz", []), email, fn huddl, email ->
      {_filename, content} = ICS.updated_huddl(huddl)

      attachment(
        email,
        Swoosh.Attachment.new({:data, content},
          filename: "huddl-#{huddl["huddl_id"]}.ics",
          content_type: "text/calendar"
        )
      )
    end)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "the next instance"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
