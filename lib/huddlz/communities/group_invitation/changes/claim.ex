defmodule Huddlz.Communities.GroupInvitation.Changes.Claim do
  @moduledoc false
  use Ash.Resource.Change

  alias Huddlz.Communities.GroupInvitation
  alias Huddlz.Communities.GroupInvitation.Checks.EmailRecipient

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      # LockPending holds the row lock. Recheck identity against persisted data
      # so simultaneous visits cannot rebind the invitation or notify twice.
      invitation = Ash.get!(GroupInvitation, changeset.data.id, authorize?: false)

      if EmailRecipient.match?(actor, %{subject: %{changeset | data: invitation}}, []) do
        Ash.Changeset.force_change_attribute(changeset, :invitee_id, actor.id)
      else
        Ash.Changeset.add_error(changeset, field: :token, message: "invitation is unavailable")
      end
    end)
  end
end
