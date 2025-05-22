defmodule Huddlz.Communities.Group.Changes.AddOwnerAsMember do
  @moduledoc """
  Automatically adds the owner as a member of the group after creation.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, group ->
      # Automatically add the owner as a member with owner role
      Huddlz.Communities.GroupMember
      |> Ash.Changeset.for_create(:add_member, %{
        group_id: group.id,
        user_id: group.owner_id,
        role: "owner"
      })
      |> Ash.create!(authorize?: false)

      {:ok, group}
    end)
  end
end
