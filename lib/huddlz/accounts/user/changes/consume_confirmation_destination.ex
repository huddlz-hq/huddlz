defmodule Huddlz.Accounts.User.Changes.ConsumeConfirmationDestination do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(
      &Ash.Changeset.force_change_attribute(&1, :confirmation_destination, nil)
    )
    |> Ash.Changeset.after_action(fn changeset, user ->
      {:ok,
       Ash.Resource.put_metadata(
         user,
         :confirmation_destination,
         changeset.data.confirmation_destination
       )}
    end)
  end
end
