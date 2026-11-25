defmodule Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs do
  @moduledoc """
  Calculates starts_at and ends_at from separate date, time, and duration inputs.
  Only applies when the virtual arguments are provided.
  """

  use Ash.Resource.Change

  alias Huddlz.TimeZone

  def change(changeset, _opts, _context) do
    date = Ash.Changeset.get_argument(changeset, :date)
    start_time = Ash.Changeset.get_argument(changeset, :start_time)
    duration_minutes = Ash.Changeset.get_argument(changeset, :duration_minutes)
    time_zone = Ash.Changeset.get_attribute(changeset, :time_zone)

    case TimeZone.resolve_interval(date, start_time, duration_minutes, time_zone) do
      {:ok, starts_at, ends_at} ->
        changeset
        |> Ash.Changeset.change_attribute(:starts_at, starts_at)
        |> Ash.Changeset.change_attribute(:ends_at, ends_at)

      :incomplete ->
        changeset

      {:error, :daylight_saving_gap} ->
        Ash.Changeset.add_error(changeset,
          field: :start_time,
          message: "does not exist in #{time_zone} because of daylight saving time"
        )

      {:error, reason} ->
        Ash.Changeset.add_error(changeset,
          field: :start_time,
          message: "could not be scheduled: #{inspect(reason)}"
        )
    end
  end
end
