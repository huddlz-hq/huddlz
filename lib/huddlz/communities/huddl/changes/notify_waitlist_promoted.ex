defmodule Huddlz.Communities.Huddl.Changes.NotifyWaitlistPromoted do
  @moduledoc "Notifies the person promoted during RSVP cancellation in the action transaction."

  use Ash.Resource.Change

  alias Huddlz.Communities.WaitlistPromotion

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn cs, huddl ->
      WaitlistPromotion.notify(huddl, Map.get(cs.context, :promoted_user_ids, []))
      {:ok, huddl}
    end)
  end
end
