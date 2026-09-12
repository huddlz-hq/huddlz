defmodule Huddlz.Accounts.User.Changes.DiscardConfirmationLinks do
  @moduledoc """
  Once an address is confirmed, none of the account's remaining
  confirmation links should work. The strategy revokes only the link that
  was used; this removes the rest.
  """
  use Ash.Resource.Change

  alias Huddlz.Accounts.Confirmation

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      :ok = Confirmation.discard_links(user)
      {:ok, user}
    end)
  end
end
