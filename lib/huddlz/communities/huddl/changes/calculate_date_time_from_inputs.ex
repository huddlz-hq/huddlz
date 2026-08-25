defmodule Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs do
  @moduledoc """
  Calculates starts_at and ends_at from separate date, time, and duration
  inputs, interpreted as wall time in the huddl's resolved `time_zone`. Only
  applies when the virtual arguments are provided. Must run after
  `ResolveTimeZone` so `time_zone` is already resolved.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    date = Ash.Changeset.get_argument(changeset, :date)
    start_time = Ash.Changeset.get_argument(changeset, :start_time)
    duration_minutes = Ash.Changeset.get_argument(changeset, :duration_minutes)

    if date && start_time && duration_minutes do
      time_zone = Ash.Changeset.get_attribute(changeset, :time_zone) || "Etc/UTC"

      case DateTime.new(date, start_time, time_zone) do
        {:ok, starts_at} ->
          ends_at = DateTime.add(starts_at, duration_minutes, :minute)

          changeset
          |> Ash.Changeset.change_attribute(:starts_at, starts_at)
          |> Ash.Changeset.change_attribute(:ends_at, ends_at)

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
