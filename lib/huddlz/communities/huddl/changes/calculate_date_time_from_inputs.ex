defmodule Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs do
  @moduledoc """
  Calculates starts_at and ends_at from separate date, time, and duration inputs.
  Only applies when the virtual arguments are provided.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    date = Ash.Changeset.get_argument(changeset, :date)
    start_time = Ash.Changeset.get_argument(changeset, :start_time)
    duration_minutes = Ash.Changeset.get_argument(changeset, :duration_minutes)
    time_zone = Ash.Changeset.get_attribute(changeset, :time_zone) || "Etc/UTC"

    # Only calculate if all three virtual arguments are provided
    if date && start_time && duration_minutes do
      # Combine date and time into a DateTime
      # Assuming the user's input is in their local timezone, we'll use UTC for now
      # In a real app, you'd want to handle timezone conversion properly
      case build_datetime(date, start_time, time_zone) do
        {:ok, starts_at} ->
          # Calculate ends_at by adding duration
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
      # If virtual arguments aren't provided, pass through unchanged
      # This allows direct setting of starts_at/ends_at to still work
      changeset
    end
  end

  @doc false
  def build_datetime(date, time, time_zone) do
    case DateTime.new(date, time, time_zone) do
      {:ok, local_starts_at} ->
        DateTime.shift_zone(local_starts_at, "Etc/UTC")

      {:ambiguous, _first_starts_at, _second_starts_at} ->
        {:error, "is ambiguous in #{time_zone} due to daylight saving time"}

      {:gap, _before_gap, _after_gap} ->
        {:error, "does not exist in #{time_zone} due to daylight saving time"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
