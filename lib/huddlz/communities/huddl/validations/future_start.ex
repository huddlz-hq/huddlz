defmodule Huddlz.Communities.Huddl.Validations.FutureStart do
  @moduledoc """
  Requires a new huddl, or a copy, to start after now.

  Runs once the start has been resolved in the huddl time zone, so a huddl
  later today counts as future wherever it meets. A day before today flags
  the date; a start time already passed today flags the start time. A copy
  given a start timestamp instead of a date flags that timestamp.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    starts_at = Ash.Changeset.get_attribute(changeset, :starts_at)

    cond do
      is_nil(starts_at) or DateTime.after?(starts_at, DateTime.utc_now()) -> :ok
      date = Ash.Changeset.get_argument(changeset, :date) -> past_schedule(changeset, date)
      Ash.Changeset.get_argument(changeset, :copied_from_id) -> past(:starts_at)
      true -> :ok
    end
  end

  defp past_schedule(changeset, date) do
    time_zone = Ash.Changeset.get_attribute(changeset, :time_zone)

    if Date.before?(date, DateTime.to_date(DateTime.now!(time_zone))),
      do: past(:date),
      else: past(:start_time)
  end

  defp past(field), do: {:error, field: field, message: "must be in the future"}
end
