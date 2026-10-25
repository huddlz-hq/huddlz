defmodule Huddlz.Accounts.UserBlock.Changes.BlockHuddlOrganizer do
  @moduledoc """
  Blocks whoever organized the named huddl, which the actor must be able
  to see. Nobody blocks themselves.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.HuddlOrganizer

  @impl true
  def change(changeset, _opts, context) do
    actor_id = context.actor && context.actor.id
    huddl_id = Ash.Changeset.get_argument(changeset, :huddl_id)

    case HuddlOrganizer.fetch(huddl_id, context.actor) do
      {:ok, ^actor_id} ->
        Ash.Changeset.add_error(changeset, field: :huddl_id, message: "You organize this huddl.")

      {:ok, organizer_id} ->
        Ash.Changeset.force_change_attribute(changeset, :blocked_user_id, organizer_id)

      :error ->
        Ash.Changeset.add_error(changeset, field: :huddl_id, message: "This huddl is not available.")
    end
  end
end
