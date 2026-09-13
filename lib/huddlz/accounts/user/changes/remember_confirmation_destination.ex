defmodule Huddlz.Accounts.User.Changes.RememberConfirmationDestination do
  @moduledoc false
  use Ash.Resource.Change
  alias Huddlz.Accounts.ConfirmationDestination

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      destination =
        ConfirmationDestination.validate(Ash.Changeset.get_argument(changeset, :destination))

      cond do
        is_nil(destination) ->
          Ash.Changeset.add_error(changeset,
            field: :destination,
            message: "must be a huddl, group, or invitation page"
          )

        is_nil(changeset.data.confirmed_at) ->
          Ash.Changeset.force_change_attribute(changeset, :confirmation_destination, destination)

        true ->
          changeset
      end
    end)
  end
end
