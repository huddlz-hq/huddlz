defmodule Huddlz.Accounts.User.Changes.RequireCurrentConfirmationAddress do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Runs after AshAuthentication has read the address bound into the token,
    # while the account row is still locked. A signup link cannot undo a change.
    Ash.Changeset.before_action(changeset, fn changeset ->
      email = Ash.Changeset.get_attribute(changeset, :email)

      if is_nil(changeset.data.confirmed_at) and
           Ash.CiString.compare(email, changeset.data.email) == :eq do
        changeset
      else
        Ash.Changeset.add_error(changeset,
          field: :confirm,
          message: "This confirmation link is no longer valid for this address."
        )
      end
    end)
  end
end
