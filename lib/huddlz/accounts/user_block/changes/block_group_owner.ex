defmodule Huddlz.Accounts.UserBlock.Changes.BlockGroupOwner do
  @moduledoc """
  Blocks whoever owns the named group, which the actor must be able to see.
  Nobody blocks themselves.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.GroupOwner

  @impl true
  def change(changeset, _opts, context) do
    actor_id = context.actor && context.actor.id
    group_id = Ash.Changeset.get_argument(changeset, :group_id)

    case GroupOwner.fetch(group_id, context.actor) do
      {:ok, ^actor_id} ->
        Ash.Changeset.add_error(changeset, field: :group_id, message: "You own this group.")

      {:ok, owner_id} ->
        Ash.Changeset.force_change_attribute(changeset, :blocked_user_id, owner_id)

      :error ->
        Ash.Changeset.add_error(changeset,
          field: :group_id,
          message: "This group is not available."
        )
    end
  end
end
