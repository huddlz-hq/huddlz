defmodule Huddlz.Communities.Huddl.Changes.SetCreatorToActor do
  @moduledoc """
  Forces `creator_id` to the acting user so huddl authorship cannot be
  spoofed through the action input — `creator_id` is not an accepted
  attribute on `:create`, the creator is always the actor.

  Implemented as a `before_action` hook (rather than the builtin
  `relate_actor/1`) so the actor lookup is deferred until after Ash has
  propagated `actor:` from either `for_create` opts or `Ash.create/2` opts
  to the changeset's private context.

  When no actor is present — internal seeding and recurring-series
  generation that run with `authorize?: false` and set `creator_id`
  directly via `force_change_attribute/3` — the existing `creator_id` is
  left untouched so a generated series inherits its parent's creator.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      case cs.context[:private][:actor] do
        %{id: id} when is_binary(id) ->
          Ash.Changeset.force_change_attribute(cs, :creator_id, id)

        _ ->
          cs
      end
    end)
  end
end
