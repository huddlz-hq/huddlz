defmodule Huddlz.Communities.GroupMember.Checks.PublicGroup do
  @moduledoc """
  Check if a group is public. Used to ensure users can only join public groups.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "group is public"
  end

  @impl true
  def match?(_actor, %{changeset: changeset}, _opts) do
    case changeset.arguments[:group_id] do
      nil ->
        false

      group_id ->
        case Huddlz.Communities.Group |> Ash.get(group_id) do
          {:ok, group} -> group.is_public == true
          _ -> false
        end
    end
  end

  def match?(_actor, _context, _opts) do
    false
  end
end
