defmodule Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroups do
  @moduledoc """
  Forces is_private to true if the group is private.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Group

  def change(changeset, _opts, _context) do
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
