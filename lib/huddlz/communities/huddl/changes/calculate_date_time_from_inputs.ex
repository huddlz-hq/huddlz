defmodule Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs do
  @moduledoc """
  Calculates starts_at and ends_at from separate date, time, and duration
  inputs, interpreted as wall time in the huddl's resolved `time_zone`. Only
  applies when the virtual arguments are provided. Must run after
  `ResolveTimeZone` so `time_zone` is already resolved.

  Daylight saving transitions are handled by
  `Huddlz.DateTimeFormatting.resolve_wall_time/3`: an ambiguous wall time
  (the hour a fall-back transition repeats) takes the earlier instant, while
  a nonexistent one (the hour a spring-forward transition skips) is a
  validation error on `:start_time` — there is no instant to store.
  """

  use Ash.Resource.Change

  alias Huddlz.DateTimeFormatting

  def change(changeset, _opts, _context) do
    date = Ash.Changeset.get_argument(changeset, :date)
    start_time = Ash.Changeset.get_argument(changeset, :start_time)
    duration_minutes = Ash.Changeset.get_argument(changeset, :duration_minutes)

    if date && start_time && duration_minutes do
      time_zone = Ash.Changeset.get_attribute(changeset, :time_zone) || "Etc/UTC"

      case DateTimeFormatting.resolve_wall_time(date, start_time, time_zone) do
        {:ok, starts_at} ->
          ends_at = DateTime.add(starts_at, duration_minutes, :minute)

          changeset
          |> Ash.Changeset.change_attribute(:starts_at, starts_at)
          |> Ash.Changeset.change_attribute(:ends_at, ends_at)

        {:gap, _just_before, _just_after} ->
          Ash.Changeset.add_error(changeset,
            field: :start_time,
            message:
              "doesn't exist on that date in #{time_zone} — the clocks change. Pick another time."
          )

        {:error, reason} ->
          Ash.Changeset.add_error(changeset,
            field: :start_time,
            message: "Invalid date/time combination: #{reason}"
          )
      end
    else
      changeset
    end
  end
end
