defmodule Huddlz.Communities.Huddl.Calculations.Turnout do
  @moduledoc """
  Derived turnout figures for a huddl.

    * `field: :total` — people in the room plus people on the call.
    * `field: :show_rate` — total turnout as a whole-number percentage of
      the huddl's RSVPs (waitlist excluded). It can exceed 100 when more
      people came than RSVPd.

  Both are `nil` until turnout has been recorded, and the show rate is
  also `nil` when the huddl had no RSVPs to compare against.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    if opts[:field] in [:total, :show_rate] do
      {:ok, opts}
    else
      {:error, "field must be :total or :show_rate"}
    end
  end

  @impl true
  def load(_query, _opts, _context) do
    [:rsvp_count, :turnout_in_room, :turnout_on_call, :turnout_recorded_at]
  end

  @impl true
  def calculate(records, opts, _context) do
    Enum.map(records, &value(&1, opts[:field]))
  end

  defp value(%{turnout_recorded_at: nil}, _field), do: nil

  # Field policies hand non-organizers a forbidden marker instead of the
  # counts; the derived figures are forbidden to them as well, so stay nil.
  defp value(%{turnout_recorded_at: %Ash.ForbiddenField{}}, _field), do: nil

  defp value(huddl, :total), do: total(huddl)

  defp value(%{rsvp_count: rsvps}, :show_rate) when rsvps in [nil, 0], do: nil

  defp value(%{rsvp_count: rsvps} = huddl, :show_rate) do
    round(total(huddl) * 100 / rsvps)
  end

  defp total(huddl), do: (huddl.turnout_in_room || 0) + (huddl.turnout_on_call || 0)
end
