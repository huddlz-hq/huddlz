defmodule Huddlz.Communities.Huddl.CopySuggestion do
  @moduledoc """
  Suggests a date for a copy of a huddl: the first date on the source's
  weekday that falls after both today and the source's own date, in the
  source's time zone.

  A past huddl suggests its next weekday from today; an upcoming one
  suggests the week after it.
  """

  alias Huddlz.Communities.Huddl

  @doc "The suggested date for copying `huddl`, relative to `today` in its time zone."
  def date(%Huddl{} = huddl, today \\ nil) do
    source_date = huddl.starts_at |> DateTime.shift_zone!(huddl.time_zone) |> DateTime.to_date()
    today = today || huddl.time_zone |> DateTime.now!() |> DateTime.to_date()
    after_date = Enum.max([today, source_date], Date)

    Date.add(after_date, days_until_weekday(after_date, Date.day_of_week(source_date)))
  end

  defp days_until_weekday(date, weekday) do
    case Integer.mod(weekday - Date.day_of_week(date), 7) do
      0 -> 7
      days -> days
    end
  end
end
