defmodule Huddlz.Communities.Huddl.Calculations.ActorIsMember do
  @moduledoc """
  Calculates whether the current actor is a member of the huddl's group.
  """
  use Ash.Resource.Calculation

  alias Huddlz.Communities.GroupMember
  require Ash.Query

  @impl true
  def load(_query, _opts, _context) do
    [:group_id]
  end

  @impl true
  def calculate(records, _opts, %{actor: nil}) do
    # No actor means not a member
    Enum.map(records, fn _ -> false end)
  end

  @impl true
  def calculate(records, _opts, %{actor: actor}) do
    # Get all unique group IDs from the records
    group_ids =
      records
      |> Enum.map(& &1.group_id)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    # Find which groups the actor is a member of
    member_group_ids =
      if Enum.empty?(group_ids) do
        []
      else
        GroupMember
        |> Ash.Query.filter(user_id == ^actor.id and group_id in ^group_ids)
        |> Ash.Query.select([:group_id])
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.group_id)
        |> MapSet.new()
      end

    # Return whether the actor is a member for each record
    Enum.map(records, fn record ->
      record.group_id != nil && MapSet.member?(member_group_ids, record.group_id)
    end)
  end
end
