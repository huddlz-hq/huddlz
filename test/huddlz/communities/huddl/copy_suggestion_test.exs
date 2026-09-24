defmodule Huddlz.Communities.Huddl.CopySuggestionTest do
  use ExUnit.Case, async: true

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.CopySuggestion

  # Wednesday, September 23, 2026
  @today ~D[2026-09-23]

  defp huddl_on(date, time \\ ~T[18:30:00], time_zone \\ "America/Los_Angeles") do
    starts_at = date |> DateTime.new!(time, time_zone) |> DateTime.shift_zone!("Etc/UTC")
    %Huddl{starts_at: starts_at, time_zone: time_zone}
  end

  test "a past huddl suggests its weekday's next date after today" do
    # Thursday, August 20
    assert CopySuggestion.date(huddl_on(~D[2026-08-20]), @today) == ~D[2026-09-24]
  end

  test "a past huddl on today's weekday suggests a week from today" do
    # Wednesday, September 16
    assert CopySuggestion.date(huddl_on(~D[2026-09-16]), @today) == ~D[2026-09-30]
  end

  test "an upcoming huddl suggests the week after it" do
    # Thursday, October 15
    assert CopySuggestion.date(huddl_on(~D[2026-10-15]), @today) == ~D[2026-10-22]
  end

  test "a huddl happening today suggests a week later" do
    assert CopySuggestion.date(huddl_on(@today), @today) == ~D[2026-09-30]
  end

  test "the weekday is the huddl's own, not UTC's" do
    # 8:30 PM Tuesday in Los Angeles is already Wednesday in UTC.
    assert CopySuggestion.date(huddl_on(~D[2026-09-15], ~T[20:30:00]), @today) ==
             ~D[2026-09-29]
  end
end
