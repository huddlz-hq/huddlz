defmodule Huddlz.Communities.Huddl.SeriesWindowTest do
  use ExUnit.Case, async: true

  alias Huddlz.Communities.Huddl.SeriesWindow
  alias Huddlz.Communities.HuddlTemplate

  @zone "America/New_York"

  defp template(overrides \\ []) do
    struct!(
      HuddlTemplate,
      Keyword.merge(
        [
          starts_at_local: ~N[2030-01-07 18:30:00],
          ends_at_local: ~N[2030-01-07 19:30:00],
          time_zone: @zone,
          interval: 1,
          unit: :week,
          repeat_until: nil
        ],
        overrides
      )
    )
  end

  defp at(naive), do: naive |> DateTime.from_naive!(@zone) |> DateTime.shift_zone!("Etc/UTC")

  defp local_dates(occurrences) do
    Enum.map(occurrences, fn {starts_at, _ends_at} ->
      starts_at |> DateTime.shift_zone!(@zone) |> DateTime.to_date()
    end)
  end

  describe "next_occurrences/3 weekly" do
    test "returns twelve dates a week apart starting with the first after the cutoff" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(template(), at(~N[2030-01-06 12:00:00]))

      assert local_dates(occurrences) == [
               ~D[2030-01-07],
               ~D[2030-01-14],
               ~D[2030-01-21],
               ~D[2030-01-28],
               ~D[2030-02-04],
               ~D[2030-02-11],
               ~D[2030-02-18],
               ~D[2030-02-25],
               ~D[2030-03-04],
               ~D[2030-03-11],
               ~D[2030-03-18],
               ~D[2030-03-25]
             ]
    end

    test "skips occurrences at or before the cutoff" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(template(), at(~N[2030-01-21 18:30:00]), 2)

      assert local_dates(occurrences) == [~D[2030-01-28], ~D[2030-02-04]]
    end

    test "honours an interval of two weeks" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(interval: 2),
                 at(~N[2030-01-06 12:00:00]),
                 3
               )

      assert local_dates(occurrences) == [~D[2030-01-07], ~D[2030-01-21], ~D[2030-02-04]]
    end

    test "carries the anchor's duration onto every occurrence" do
      assert {:ok, [{starts_at, ends_at} | _]} =
               SeriesWindow.next_occurrences(template(), at(~N[2030-01-06 12:00:00]), 1)

      assert DateTime.diff(ends_at, starts_at, :second) == 3600
    end

    test "stops at repeat_until" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(repeat_until: ~D[2030-02-04]),
                 at(~N[2030-01-06 12:00:00])
               )

      assert local_dates(occurrences) == [
               ~D[2030-01-07],
               ~D[2030-01-14],
               ~D[2030-01-21],
               ~D[2030-01-28],
               ~D[2030-02-04]
             ]
    end

    test "returns nothing when repeat_until is already past" do
      assert {:ok, []} =
               SeriesWindow.next_occurrences(
                 template(repeat_until: ~D[2029-12-01]),
                 at(~N[2030-01-06 12:00:00])
               )
    end

    # Review Focus 4: the arithmetic index must not depend on walking the series.
    test "finds the right date a decade after the anchor" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(
                   starts_at_local: ~N[2020-01-06 18:30:00],
                   ends_at_local: ~N[2020-01-06 19:30:00]
                 ),
                 at(~N[2030-01-01 12:00:00]),
                 2
               )

      assert local_dates(occurrences) == [~D[2030-01-07], ~D[2030-01-14]]
    end
  end

  describe "next_occurrences/3 monthly" do
    # Review Focus 4: clamping through February, from an anchor on the 31st.
    test "keeps the selected day and clamps short months" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(
                   starts_at_local: ~N[2028-01-31 18:30:00],
                   ends_at_local: ~N[2028-01-31 19:30:00],
                   unit: :month
                 ),
                 at(~N[2028-01-01 12:00:00]),
                 4
               )

      assert local_dates(occurrences) == [
               ~D[2028-01-31],
               ~D[2028-02-29],
               ~D[2028-03-31],
               ~D[2028-04-30]
             ]
    end

    test "clamps to February 28 in a non-leap year" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(
                   starts_at_local: ~N[2027-01-31 18:30:00],
                   ends_at_local: ~N[2027-01-31 19:30:00],
                   unit: :month
                 ),
                 at(~N[2027-02-01 12:00:00]),
                 2
               )

      assert local_dates(occurrences) == [~D[2027-02-28], ~D[2027-03-31]]
    end

    test "finds the right month years after the anchor" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(
                   starts_at_local: ~N[2020-03-15 18:30:00],
                   ends_at_local: ~N[2020-03-15 19:30:00],
                   unit: :month
                 ),
                 at(~N[2030-06-20 12:00:00]),
                 2
               )

      assert local_dates(occurrences) == [~D[2030-07-15], ~D[2030-08-15]]
    end
  end

  describe "next_occurrences/3 daylight saving" do
    # Review Focus 5: a gap must shift the occurrence, not end the series.
    test "shifts an occurrence out of a spring-forward gap and keeps going" do
      assert {:ok, occurrences} =
               SeriesWindow.next_occurrences(
                 template(
                   starts_at_local: ~N[2030-03-03 02:30:00],
                   ends_at_local: ~N[2030-03-03 03:30:00]
                 ),
                 at(~N[2030-03-04 12:00:00]),
                 2
               )

      [{gap_start, gap_ends}, {next_start, _}] = occurrences

      assert gap_start |> DateTime.shift_zone!(@zone) |> DateTime.to_time() == ~T[03:00:00]

      # The nominal span is 02:30-03:30. Only the start falls in the gap, so
      # only it moves forward; the end resolves unchanged, compressing this
      # occurrence to thirty minutes. That's deliberate: every occurrence
      # resolves in local wall-clock terms, and changing that to preserve
      # absolute duration would alter every occurrence spanning a DST
      # boundary, not just this one.
      assert gap_ends |> DateTime.shift_zone!(@zone) |> DateTime.to_time() == ~T[03:30:00]

      assert local_dates(occurrences) == [~D[2030-03-10], ~D[2030-03-17]]
      assert next_start |> DateTime.shift_zone!(@zone) |> DateTime.to_time() == ~T[02:30:00]
    end
  end

  describe "next_occurrences/3 edge cases" do
    test "returns an empty list for a count of zero" do
      assert {:ok, []} =
               SeriesWindow.next_occurrences(template(), at(~N[2030-01-06 12:00:00]), 0)
    end

    test "reports an unresolvable time zone" do
      assert {:error, message} =
               SeriesWindow.next_occurrences(
                 template(time_zone: "Not/AZone"),
                 ~U[2030-01-06 12:00:00Z],
                 1
               )

      assert message =~ "Not/AZone"
    end
  end
end
