defmodule Huddlz.Accounts.User.Changes.QueueConfirmedInvitations do
  @moduledoc false
  use Ash.Resource.Change

  alias Huddlz.Communities.GroupInvitation.ConfirmedRecipientWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      # The successful confirmation action supplies proof for this exact address.
      # A pending replacement has not yet established ownership of its new inbox.
      with {:ok, _job} <-
             Oban.insert(
               ConfirmedRecipientWorker.new(%{
                 user_id: user.id,
                 email: to_string(user.email)
               })
             ) do
        {:ok, user}
      end
    end)
  end
end
