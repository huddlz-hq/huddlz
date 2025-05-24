defmodule Huddlz.Communities.Huddl.Calculations.VisibleVirtualLink do
  @moduledoc """
  Returns the virtual link only if the actor has RSVPed to the huddl.
  Virtual links are only visible to attendees who have confirmed their attendance.
  """
  use Ash.Resource.Calculation

  alias Huddlz.Communities.HuddlAttendee
  require Ash.Query

  def calculate(records, _opts, %{actor: nil}) do
    # Non-authenticated users can't see virtual links
    Enum.map(records, fn _ -> nil end)
  end

  def calculate(records, _opts, %{actor: actor}) do
    # Get all unique huddl IDs from the records
    huddl_ids =
      records
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    # Check which huddlz the user has RSVPed to
    rsvped_huddl_ids =
      HuddlAttendee
      |> Ash.Query.for_read(:read, %{}, authorize?: false)
      |> Ash.Query.filter(user_id: actor.id)
      |> Ash.Query.filter(huddl_id: [in: huddl_ids])
      |> Ash.read!(actor: actor, authorize?: false)
      |> Enum.map(& &1.huddl_id)
      |> MapSet.new()

    # Return virtual link only for huddlz where user has RSVPed
    Enum.map(records, fn record ->
      if MapSet.member?(rsvped_huddl_ids, record.id) do
        record.virtual_link
      else
        nil
      end
    end)
  end

  def select(_query, _opts, _context) do
    [:virtual_link, :id]
  end

  def load(_query, _opts, _context) do
    []
  end
end
