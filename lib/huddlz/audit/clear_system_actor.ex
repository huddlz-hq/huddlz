defmodule Huddlz.Audit.ClearSystemActor do
  @moduledoc "Keeps an authorization identity from being recorded as a human initiator of system work."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if get_in(changeset.context, [:shared, :audit_system_action?]) == true do
      Ash.Changeset.force_change_attribute(changeset, :actor_id, nil)
    else
      changeset
    end
  end
end
