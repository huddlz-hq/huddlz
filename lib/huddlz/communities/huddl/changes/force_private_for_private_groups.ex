defmodule Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroups do
  @moduledoc """
  Forces is_private to true if the group is private.

  On update, only runs when is_private is being changed — the group lookup
  isn't worth a query on every unrelated edit (and would run once per
  occurrence when editing a whole recurring series).
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Group

  def change(changeset, _opts, _context) do
    if changeset.action_type == :update and
         not Ash.Changeset.changing_attribute?(changeset, :is_private) do
      changeset
    else
      force_private_if_group_private(changeset)
    end
  end

  defp force_private_if_group_private(changeset) do
    with group_id when not is_nil(group_id) <- Ash.Changeset.get_attribute(changeset, :group_id),
         {:ok, group} <- Ash.get(Group, group_id, authorize?: false) do
      changeset = Ash.Changeset.set_context(changeset, %{group: group})

      if group.is_public do
        changeset
      else
        Ash.Changeset.force_change_attribute(changeset, :is_private, true)
      end
    else
      _ -> changeset
    end
  end
end
