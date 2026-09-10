defmodule Huddlz.Communities.Group.Changes.SetOwnerToActor do
  @moduledoc """
  Forces `owner_id` to the current actor's id at action time.

  Implemented as a `before_action` hook (rather than the builtin
  `relate_actor/1` change) so the actor lookup is deferred until after
  Ash has propagated `actor:` from either `for_create` opts or
  `Ash.create/2` opts to the changeset's private context. The builtin
  runs at the wrong phase to see actors set on `Ash.create/2`.

  Errors out if no actor is present.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      case cs.context[:private][:actor] do
        %{id: id} when is_binary(id) ->
          Ash.Changeset.force_change_attribute(cs, :owner_id, id)

        _ ->
          Ash.Changeset.add_error(cs,
            field: :owner_id,
            message: "an authenticated actor is required to create a group"
          )
      end
    end)
  end
end
