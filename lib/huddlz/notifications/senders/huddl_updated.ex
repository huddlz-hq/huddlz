defmodule Huddlz.Notifications.Senders.HuddlUpdated do
  @moduledoc """
  Sender for C2: a huddl the recipient RSVP'd to was meaningfully
  updated.

  Sent to every RSVP'd user except the actor. Activity category —
  preferences and the unsubscribe footer apply. When the payload
  carries the full schedule an updated `.ics` is attached.

  Required payload keys:

    * `"huddl_id"`, `"huddl_title"`, `"starts_at_iso"`, `"group_name"`,
      `"group_slug"`, `"changed_fields"`.
  """

  @behaviour Huddlz.Notifications.Sender

  import Swoosh.Email, only: [attachment: 2]

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.HuddlAccess
  alias Huddlz.Notifications.ICS
  alias Huddlz.Notifications.Layout
  alias Huddlz.Notifications.Senders.ChangedFields
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    payload =
      Map.put(
        payload,
        "virtual_link",
        HuddlAccess.virtual_link(payload["huddl_id"], user)
      )

    Layout.email(%{
      to: user.email,
      subject: "Updated: #{huddl_title(payload)}",
      kicker: "Updated · #{group_name(payload)}",
      title: Layout.sentence_case(huddl_title(payload)),
      paragraphs: [
        [
          "Hi #{user.display_name}, ",
          {:strong, huddl_title(payload)},
          " with ",
          {:strong, group_name(payload)},
          " has been updated."
        ],
        ["What changed: ", {:strong, ChangedFields.summary(payload)}, "."]
      ],
      facts: Layout.huddl_facts(payload),
      action: {"See the latest details", Urls.huddl_url(payload)},
      aside: calendar_aside(payload),
      footer: Footer.activity(user, :huddl_updated)
    })
    |> maybe_attach_calendar(payload)
  end

  defp calendar_aside(%{"ends_at_iso" => ends_at}) when is_binary(ends_at),
    do: "An updated calendar event is attached."

  defp calendar_aside(_), do: nil

  defp maybe_attach_calendar(
         email,
         %{
           "huddl_id" => id,
           "huddl_title" => title,
           "starts_at_iso" => starts_at,
           "ends_at_iso" => ends_at
         } = payload
       )
       when is_binary(id) and is_binary(title) and is_binary(starts_at) and is_binary(ends_at) do
    {ics_filename, ics_content} = ICS.updated_huddl(payload)

    attachment(
      email,
      Swoosh.Attachment.new({:data, ics_content},
        filename: ics_filename,
        content_type: "text/calendar"
      )
    )
  end

  defp maybe_attach_calendar(email, _payload), do: email

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "a huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"
end
