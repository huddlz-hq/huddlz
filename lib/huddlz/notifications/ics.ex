defmodule Huddlz.Notifications.ICS do
  @moduledoc """
  Generates `.ics` (iCalendar) attachments for huddl reminder and confirmation
  emails.

  Used by senders that need to give the recipient a "Add to calendar" experience
  (E3 RSVP confirmation, D1 24-hour reminder, D2 1-hour reminder).
  """

  alias Huddlz.Communities.Huddl

  @doc """
  Build an .ics attachment payload for a single huddl.

  Returns `{filename, content}` where `content` is a UTF-8 binary suitable for
  passing to `Swoosh.Email.attachment/2` as the `body`.
  """
  @spec event_for(Huddl.t()) :: {String.t(), String.t()}
  def event_for(%Huddl{} = huddl) do
    event = %ICal.Event{
      uid: "huddl-#{huddl.id}@huddlz.com",
      dtstamp: DateTime.utc_now() |> DateTime.truncate(:second),
      dtstart: DateTime.truncate(huddl.starts_at, :second),
      dtend: DateTime.truncate(huddl.ends_at, :second),
      summary: huddl.title,
      description: build_description(huddl),
      location: build_location(huddl),
      url: huddl.virtual_link
    }

    calendar =
      %ICal{events: [event]}
      |> ICal.set_vendor("huddlz")

    content = calendar |> ICal.to_ics() |> IO.iodata_to_binary()
    {"huddl.ics", content}
  end

  defp build_description(%Huddl{description: nil, virtual_link: nil}), do: ""
  defp build_description(%Huddl{description: nil, virtual_link: link}), do: "Join: #{link}"
  defp build_description(%Huddl{description: desc, virtual_link: nil}), do: desc

  defp build_description(%Huddl{description: desc, virtual_link: link}) do
    "#{desc}\n\nJoin: #{link}"
  end

  defp build_location(%Huddl{physical_location: nil, virtual_link: link}) when is_binary(link),
    do: link

  defp build_location(%Huddl{physical_location: place}), do: place
end
