defmodule Huddlz.Scheduling.LocalDateTime do
  @moduledoc """
  Resolves organizer-entered wall-clock values in an IANA time zone.

  Daylight-saving gaps are advanced by the size of the gap. Ambiguous values
  remain an explicit domain outcome so the caller can ask which occurrence the
  organizer intends.
  """

  defstruct [:kind, :requested, :selected, :earlier, :later, :time_zone]

  @type occurrence :: :earlier | :later
  @type kind :: :exact | :gap | :ambiguous
  @type t :: %__MODULE__{
          kind: kind(),
          requested: NaiveDateTime.t(),
          selected: DateTime.t() | nil,
          earlier: DateTime.t() | nil,
          later: DateTime.t() | nil,
          time_zone: String.t()
        }

  @spec resolve(Date.t(), Time.t(), String.t(), occurrence()) ::
          {:ok, t()} | {:error, term()}
  def resolve(date, time, time_zone, occurrence \\ :earlier) do
    naive = NaiveDateTime.new!(date, time)

    case DateTime.from_naive(naive, time_zone) do
      {:ok, datetime} ->
        {:ok,
         %__MODULE__{
           kind: :exact,
           requested: naive,
           selected: datetime,
           time_zone: time_zone
         }}

      {:gap, before_gap, after_gap} ->
        resolve_gap(naive, time_zone, before_gap, after_gap)

      {:ambiguous, earlier, later} ->
        {:ok,
         %__MODULE__{
           kind: :ambiguous,
           requested: naive,
           selected: select_occurrence(occurrence, earlier, later),
           earlier: earlier,
           later: later,
           time_zone: time_zone
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_gap(naive, time_zone, before_gap, after_gap) do
    gap_seconds = utc_offset(after_gap) - utc_offset(before_gap)
    resolved_naive = NaiveDateTime.add(naive, gap_seconds, :second)

    case DateTime.from_naive(resolved_naive, time_zone) do
      {:ok, resolved} ->
        {:ok,
         %__MODULE__{
           kind: :gap,
           requested: naive,
           selected: resolved,
           time_zone: time_zone
         }}

      unexpected ->
        {:error, {:invalid_gap_resolution, unexpected}}
    end
  end

  defp select_occurrence(:later, _earlier, later), do: later
  defp select_occurrence(_occurrence, earlier, _later), do: earlier

  defp utc_offset(datetime), do: datetime.utc_offset + datetime.std_offset
end
