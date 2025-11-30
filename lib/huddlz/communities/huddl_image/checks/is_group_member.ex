defmodule Huddlz.Communities.HuddlImage.Checks.IsGroupMember do
  @moduledoc """
  Check that verifies the actor is a member of the group (or the group owner).
  Used for create_pending action on huddl images where the group_id is passed as an argument.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is a member of the group"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: changeset}, _opts) do
    group_id = Ash.Changeset.get_argument(changeset, :group_id)
    group_member_or_owner?(actor, group_id)
  end

  def match?(_actor, _context, _opts), do: false

  defp group_member_or_owner?(_actor, nil), do: false

  defp group_member_or_owner?(actor, group_id) do
    group_owner?(actor, group_id) or group_member?(actor, group_id)
  end

  defp group_owner?(actor, group_id) do
    Group
    |> Ash.Query.filter(id == ^group_id and owner_id == ^actor.id)
    |> Ash.exists?(authorize?: false)
  end

  defp group_member?(actor, group_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^actor.id)
    |> Ash.exists?(authorize?: false)
  end
end
