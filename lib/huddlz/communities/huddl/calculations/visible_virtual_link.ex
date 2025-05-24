defmodule Huddlz.Communities.Huddl.Calculations.VisibleVirtualLink do
  @moduledoc """
  Returns the virtual link only if the actor is allowed to see it.
  For now, only group members can see virtual links.
  In the future, this will be restricted to RSVPed attendees.
  """
  use Ash.Resource.Calculation

  alias Huddlz.Communities.GroupMember
  require Ash.Query

  def calculate(records, _opts, %{actor: nil}) do
    # Non-authenticated users can't see virtual links
    Enum.map(records, fn _ -> nil end)
  end

  def calculate(records, _opts, %{actor: actor}) do
    # Get all unique group IDs from the records
    group_ids =
      records
      |> Enum.map(& &1.group_id)
      |> Enum.uniq()

    # Check which groups the user is a member of
    member_group_ids =
      GroupMember
      |> Ash.Query.for_read(:read, %{}, authorize?: false)
      |> Ash.Query.filter(user_id: actor.id)
      |> Ash.Query.filter(group_id: [in: group_ids])
      |> Ash.read!(actor: actor, authorize?: false)
      |> Enum.map(& &1.group_id)
      |> MapSet.new()

    # Return virtual link only for groups where user is a member
    Enum.map(records, fn record ->
      if MapSet.member?(member_group_ids, record.group_id) do
        record.virtual_link
      else
        nil
      end
    end)
  end

  def select(_query, _opts, _context) do
    [:virtual_link, :group_id]
  end

  def load(_query, _opts, _context) do
    []
  end
end
