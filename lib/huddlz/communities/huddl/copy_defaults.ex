defmodule Huddlz.Communities.Huddl.CopyDefaults do
  @moduledoc "Details and schedule values a new huddl inherits from its source."

  @copied_attributes [
    :title,
    :description,
    :event_type,
    :group_location_id,
    :virtual_link,
    :is_private,
    :thumbnail_url,
    :max_attendees
  ]

  def attributes(source), do: Map.take(source, @copied_attributes)

  def duration_minutes(source), do: DateTime.diff(source.ends_at, source.starts_at, :minute)

  def local_start_time(source) do
    source.starts_at
    |> DateTime.shift_zone!(source.time_zone)
    |> DateTime.to_time()
  end
end
