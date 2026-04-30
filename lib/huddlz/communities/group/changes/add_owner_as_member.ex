defmodule Huddlz.Communities.Group.Changes.AddOwnerAsMember do
  @moduledoc """
  Automatically adds the owner as a member of the group after creation.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn cs, group ->
      # Automatically add the owner as a member with owner role.
      # Pass the actor (the new owner) through so any add-member side
      # effects can recognise this as a self-add and skip notifications.
      actor = cs.context[:private][:actor]

      Huddlz.Communities.GroupMember
      |> Ash.Changeset.for_create(
        :add_member,
        %{
          group_id: group.id,
          user_id: group.owner_id,
          role: "owner"
        },
        actor: actor
      )
      |> Ash.create!(authorize?: false)

      {:ok, group}
    end)
  end
end
