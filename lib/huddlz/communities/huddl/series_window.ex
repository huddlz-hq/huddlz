defmodule Huddlz.Communities.Huddl.SeriesWindow do
  @moduledoc """
  The dates a recurring series should occupy.

  A series is defined by its `HuddlTemplate`: an anchor (`starts_at_local` and
  `ends_at_local`), a cadence (`interval` and `unit`) and an optional
  `repeat_until`. Occurrence *k* is the anchor shifted by `interval * k` weeks
  or months, so occurrence 0 is the series' first huddl. Measuring every shift
  from the anchor is what keeps a monthly series on its selected day: January
  31 clamps to February 28 or 29, and March restores the 31st.

  A boundless series has no last occurrence, so this module never walks a
  series from the beginning. It computes the index of the first occurrence
  after a cutoff arithmetically and takes a fixed count from there, which costs
  the same whether the series started last week or six years ago.
  """

  alias Huddlz.TimeZone

  @horizon 12

  @doc "How many future occurrences a series keeps materialized."
  def horizon, do: @horizon

  @doc """
  The next `count` occurrences strictly after `cutoff`, as `{starts_at, ends_at}`
  pairs in `Etc/UTC`, earliest first.

  Returns fewer than `count` when `repeat_until` cuts the series off. An
  occurrence whose local time falls in a daylight saving gap is resolved
  forward to the first valid local time rather than failing the series.
  """
  def next_occurrences(template, cutoff, count \\ @horizon)

  def next_occurrences(_template, _cutoff, count) when count <= 0, do: {:ok, []}

  def next_occurrences(template, cutoff, count) do
    case DateTime.shift_zone(cutoff, template.time_zone) do
      {:ok, local_cutoff} ->
        cutoff_local = DateTime.to_naive(local_cutoff)
        collect(template, first_index_after(template, cutoff_local), count, [])

      {:error, reason} ->
        {:error, unresolvable(template.time_zone, reason)}
    end
  end

  defp collect(_template, _index, 0, acc), do: {:ok, Enum.reverse(acc)}

  defp collect(template, index, remaining, acc) do
    starts_at_local = occurrence_local(template, index)

    if past_repeat_until?(template, starts_at_local) do
      {:ok, Enum.reverse(acc)}
    else
      duration = NaiveDateTime.diff(template.ends_at_local, template.starts_at_local, :second)
      ends_at_local = NaiveDateTime.add(starts_at_local, duration, :second)

      with {:ok, starts_at} <- resolve(starts_at_local, template.time_zone),
           {:ok, ends_at} <- resolve(ends_at_local, template.time_zone) do
        occurrence = {utc(starts_at), utc(ends_at)}
        collect(template, index + 1, remaining - 1, [occurrence | acc])
      end
    end
  end

  defp utc(datetime), do: DateTime.shift_zone!(datetime, "Etc/UTC")

  defp resolve(local, time_zone) do
    case TimeZone.resolve_local_forward(local, time_zone) do
      {:ok, datetime} -> {:ok, datetime}
      {:error, reason} -> {:error, unresolvable(time_zone, reason)}
    end
  end

  defp unresolvable(time_zone, reason) do
    "could not resolve recurring huddl time in #{time_zone}: #{inspect(reason)}"
  end

  defp occurrence_local(%{unit: :week, interval: interval} = template, index) do
    NaiveDateTime.shift(template.starts_at_local, week: interval * index)
  end

  defp occurrence_local(%{unit: :month, interval: interval} = template, index) do
    NaiveDateTime.shift(template.starts_at_local, month: interval * index)
  end

  # Estimate the index arithmetically, then correct it. The weekly estimate is
  # exact. The monthly one can be a step out where clamping shortens a month,
  # so the correction walks at most a step or two in either direction — never
  # the length of the series.
  defp first_index_after(template, cutoff_local) do
    template
    |> estimate_index(cutoff_local)
    |> max(0)
    |> correct(template, cutoff_local)
  end

  defp estimate_index(%{unit: :week, interval: interval} = template, cutoff_local) do
    div(NaiveDateTime.diff(cutoff_local, template.starts_at_local, :day), 7 * interval)
  end

  defp estimate_index(%{unit: :month, interval: interval} = template, cutoff_local) do
    anchor = template.starts_at_local
    months = (cutoff_local.year - anchor.year) * 12 + (cutoff_local.month - anchor.month)
    div(months, interval)
  end

  defp correct(index, template, cutoff_local) do
    cond do
      not after_cutoff?(template, index, cutoff_local) ->
        correct(index + 1, template, cutoff_local)

      index > 0 and after_cutoff?(template, index - 1, cutoff_local) ->
        correct(index - 1, template, cutoff_local)

      true ->
        index
    end
  end

  defp after_cutoff?(template, index, cutoff_local) do
    NaiveDateTime.after?(occurrence_local(template, index), cutoff_local)
  end

  defp past_repeat_until?(%{repeat_until: nil}, _starts_at_local), do: false

  defp past_repeat_until?(%{repeat_until: repeat_until}, starts_at_local) do
    Date.after?(NaiveDateTime.to_date(starts_at_local), as_date(repeat_until))
  end

  defp as_date(%Date{} = date), do: date
  defp as_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
end
