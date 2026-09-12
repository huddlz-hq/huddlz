defmodule Huddlz.Communities.Periods do
  @moduledoc """
  The periods the overview pages share, and how each is cut into buckets.

  Periods are `"30d"`, `"90d"` (the default) and `"12m"`. Each is split
  into equal buckets for the sparklines: six for the day periods, twelve
  for the year. Growth charts bucket by calendar month for the year, by
  fortnight for 90 days and by week for 30 days, the last bucket running
  up to now. Month boundaries fall in the time zone given; the group
  overview uses the group's, the platform overview UTC.
  """

  @periods [
    {"30d", %{days: 30, buckets: 6, label: "30 days", growth: :week}},
    {"90d", %{days: 90, buckets: 6, label: "90 days", growth: :fortnight}},
    {"12m", %{days: 365, buckets: 12, label: "12 months", growth: :month}}
  ]
  @growth_bucket_days %{week: 7, fortnight: 14}
  @default_period "90d"

  @type period :: String.t()

  @doc "Period keys and their labels, in display order."
  def periods, do: Enum.map(@periods, fn {key, %{label: label}} -> {key, label} end)

  @doc "The period a URL parameter names, falling back to the default."
  def parse_period(param) when is_binary(param) do
    if List.keymember?(@periods, param, 0), do: param, else: @default_period
  end

  def parse_period(_), do: @default_period

  def default_period, do: @default_period

  def period_label(period), do: spec(period).label

  @doc "A period's length in days, sparkline bucket count, label and growth unit."
  def spec(period) do
    {_key, spec} = List.keyfind(@periods, period, 0) || List.keyfind(@periods, @default_period, 0)
    spec
  end

  @doc "When the period started, and when the equal period before it started."
  def starts(now, %{days: days}) do
    period_start = DateTime.add(now, -days, :day)
    {period_start, DateTime.add(period_start, -days, :day)}
  end

  @doc "`buckets + 1` instants from the start of the period up to now."
  def bucket_edges(now, %{days: days, buckets: buckets}) do
    seconds = days * 86_400
    start = DateTime.add(now, -seconds, :second)
    Enum.map(0..buckets, fn i -> DateTime.add(start, div(seconds * i, buckets), :second) end)
  end

  @doc """
  The period's growth buckets as `{label, from, to}`: twelve calendar
  months in the time zone, this month last, or whole weeks or fortnights
  from the start of the period, the last one running up to now.
  """
  def growth_buckets(now, %{growth: :month, buckets: count}, time_zone) do
    this_month = start_of_month(now, time_zone)

    starts =
      Enum.map((count - 1)..0//-1, fn back ->
        shift_months(this_month, -back, time_zone)
      end)

    starts
    |> Enum.zip(tl(starts) ++ [now])
    |> Enum.map(fn {from, to} ->
      {from |> DateTime.shift_zone!(time_zone) |> Calendar.strftime("%b"), from, to}
    end)
  end

  def growth_buckets(now, %{growth: unit, days: days}, time_zone) do
    bucket_days = @growth_bucket_days[unit]
    start = DateTime.add(now, -days, :day)

    0..(days - 1)//bucket_days
    |> Enum.map(fn offset ->
      from = DateTime.add(start, offset, :day)
      to = DateTime.add(from, bucket_days, :day)
      {label_date(from, time_zone), from, min_datetime(to, now)}
    end)
  end

  @doc """
  UTC calendar periods for the platform overview, including today so far.
  Day periods contain the named number of calendar dates; a year contains
  the current month and the preceding eleven. The previous period covers
  the same number of complete dates or months. Organizer rolling periods
  continue to use `starts/2` and `growth_buckets/3`.
  """
  def calendar_window(now, %{growth: :month, buckets: count} = spec) do
    this_month = start_of_month(now, "Etc/UTC")
    start = shift_months(this_month, 1 - count, "Etc/UTC")
    starts = Enum.map(0..(count - 1), &shift_months(start, &1, "Etc/UTC"))
    edges = starts ++ [now]

    %{
      now: now,
      spec: spec,
      start: start,
      previous_start: shift_months(start, -count, "Etc/UTC"),
      edges: edges,
      buckets: calendar_buckets(edges, "%b")
    }
  end

  def calendar_window(now, %{days: days, buckets: count, growth: unit} = spec) do
    today = now |> DateTime.to_date() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    start = DateTime.add(today, 1 - days, :day)
    edges = Enum.map(0..(count - 1), &DateTime.add(start, div(days * &1, count), :day))
    bucket_days = @growth_bucket_days[unit]
    starts = Enum.map(0..(days - 1)//bucket_days, &DateTime.add(start, &1, :day))

    %{
      now: now,
      spec: spec,
      start: start,
      previous_start: DateTime.add(start, -days, :day),
      edges: edges ++ [now],
      buckets: calendar_buckets(starts ++ [now], "%b %-d")
    }
  end

  defp calendar_buckets(edges, format) do
    edges
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] -> {Calendar.strftime(from, format), from, to} end)
  end

  @doc "Whether `t` falls on or after `from` and before `to`."
  def within?(t, from, to),
    do: DateTime.compare(t, from) != :lt and DateTime.compare(t, to) == :lt

  @doc "One point per bucket: how many timestamps fall inside it."
  def per_bucket(timestamps, edges) do
    edges
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] -> Enum.count(timestamps, &within?(&1, from, to)) end)
  end

  @doc "One point per bucket end: how many timestamps fall on or before it."
  def cumulative(timestamps, [_first | ends]) do
    Enum.map(ends, fn to -> Enum.count(timestamps, &(DateTime.compare(&1, to) != :gt)) end)
  end

  @doc "Midnight starting the current calendar month in the time zone, as UTC."
  def start_of_month(now, time_zone) do
    local = DateTime.shift_zone!(now, time_zone)

    local
    |> DateTime.to_date()
    |> Date.beginning_of_month()
    |> DateTime.new!(~T[00:00:00], time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp min_datetime(a, b), do: if(DateTime.compare(a, b) == :gt, do: b, else: a)

  defp label_date(at, time_zone),
    do: at |> DateTime.shift_zone!(time_zone) |> Calendar.strftime("%b %-d")

  defp shift_months(month_start, months, time_zone) do
    month_start
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_date()
    |> Date.shift(month: months)
    |> DateTime.new!(~T[00:00:00], time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end
end
