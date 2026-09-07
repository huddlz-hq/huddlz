defmodule Huddlz.Communities.GroupInvitation.Changes.QueueEmail do
  @moduledoc false
  use Ash.Resource.Change
  alias Huddlz.Communities.GroupInvitation.EmailWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn
      _changeset, %{invitee_id: nil} = invitation ->
        with {:ok, _job} <- Oban.insert(EmailWorker.new(%{invitation_id: invitation.id})) do
          {:ok, invitation}
        end

      _changeset, invitation ->
        {:ok, invitation}
    end)
  end
end
