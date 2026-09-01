defmodule Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs do
  @moduledoc """
  Calculates starts_at and ends_at from separate date, time, and duration inputs.
  Only applies when the virtual arguments are provided.
  """

  use Ash.Resource.Change

  alias Huddlz.Scheduling.LocalDateTime

  def change(changeset, _opts, _context) do
    date = Ash.Changeset.get_argument(changeset, :date)
    start_time = Ash.Changeset.get_argument(changeset, :start_time)
    duration_minutes = Ash.Changeset.get_argument(changeset, :duration_minutes)
    occurrence = Ash.Changeset.get_argument(changeset, :ambiguous_time_occurrence)
    time_zone = Ash.Changeset.get_attribute(changeset, :time_zone) || "Etc/UTC"

    if date && start_time && duration_minutes do
      case build_datetime(date, start_time, time_zone, occurrence) do
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

  @doc false
  def build_datetime(date, time, time_zone, occurrence \\ :earlier) do
    with {:ok, resolution} <- LocalDateTime.resolve(date, time, time_zone, occurrence) do
      DateTime.shift_zone(resolution.selected, "Etc/UTC")
    end
  end
end
