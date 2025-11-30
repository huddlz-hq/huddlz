defmodule Huddlz.Communities.GroupImage.Checks.IsGroupOwner do
  @moduledoc """
  Check that verifies the actor is the owner of the group being referenced.
  Used for create actions on group images where the relationship isn't loaded yet.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.Group

  @impl true
  def describe(_opts) do
    "actor is the owner of the group"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: changeset}, _opts) do
    group_id = Ash.Changeset.get_attribute(changeset, :group_id)
    group_owner?(actor, group_id)
  end

  def match?(_actor, _context, _opts), do: false

  defp group_owner?(_actor, nil), do: false

  defp group_owner?(actor, group_id) do
    case Ash.get(Group, group_id, authorize?: false) do
      {:ok, %Group{owner_id: owner_id}} -> actor.id == owner_id
      _ -> false
    end
  end
end
