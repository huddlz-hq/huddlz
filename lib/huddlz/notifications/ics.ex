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
    attachment_for(%{
      id: huddl.id,
      starts_at: huddl.starts_at,
      ends_at: huddl.ends_at,
      title: huddl.title,
      description: huddl.description,
      physical_location: huddl.physical_location,
      virtual_link: huddl.virtual_link
    })
  end

  @doc """
  Build an updated calendar attachment from a notification payload.

  The UID uses the same huddl identity as `event_for/1`, so calendar clients
  can recognize the attachment as an update to the existing entry.
  """
  @spec updated_huddl(map()) :: {String.t(), String.t()}
  def updated_huddl(payload) do
    attachment_for(%{
      id: Map.fetch!(payload, "huddl_id"),
      starts_at: parse_datetime!(payload, "starts_at_iso"),
      ends_at: parse_datetime!(payload, "ends_at_iso"),
      title: Map.fetch!(payload, "huddl_title"),
      description: payload["description"],
      physical_location: payload["physical_location"],
      virtual_link: payload["virtual_link"]
    })
  end

  defp attachment_for(fields) do
    event = %ICal.Event{
      uid: "huddl-#{fields.id}@huddlz.com",
      dtstamp: DateTime.utc_now() |> DateTime.truncate(:second),
      dtstart: DateTime.truncate(fields.starts_at, :second),
      dtend: DateTime.truncate(fields.ends_at, :second),
      summary: fields.title,
      description: build_description(fields.description, fields.virtual_link),
      location: build_location(fields.physical_location, fields.virtual_link),
      url: fields.virtual_link
    }

    calendar =
      %ICal{events: [event]}
      |> ICal.set_vendor("huddlz")

    content = calendar |> ICal.to_ics() |> IO.iodata_to_binary()
    {"huddl.ics", content}
  end

  defp parse_datetime!(payload, key) do
    with value when is_binary(value) <- payload[key],
         {:ok, datetime, _offset} <- DateTime.from_iso8601(value) do
      datetime
    else
      _ -> raise ArgumentError, "calendar payload requires #{inspect(key)} as an ISO 8601 time"
    end
  end

  defp build_description(nil, nil), do: ""
  defp build_description(nil, link), do: "Join: #{link}"
  defp build_description(desc, nil), do: desc

  defp build_description(desc, link) do
    "#{desc}\n\nJoin: #{link}"
  end

  defp build_location(nil, link) when is_binary(link), do: link

  defp build_location(place, _link), do: place
end
