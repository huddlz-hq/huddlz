defmodule Huddlz.Communities.GroupMember.Validations.UserExistsForRole do
  @moduledoc """
  Validates that the user exists before being assigned to any role in a group.
  This prevents assigning non-existent users as members, organizers, or owners.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_argument(changeset, :user_id)

    case Ash.get(Huddlz.Accounts.User, user_id, authorize?: false) do
      {:ok, _user} ->
        :ok

      _ ->
        {:error, field: :user_id, message: "User not found"}
    end
  end
end
