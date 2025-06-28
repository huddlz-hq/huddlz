defmodule Huddlz.Communities.GroupMember.Validations.VerifiedForElevatedRoles do
  @moduledoc """
  Validates that users exist before being assigned as owner or organizer.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    role = Ash.Changeset.get_attribute(changeset, :role)

    if role in [:owner, :organizer] do
      validate_elevated_role(changeset, role)
    else
      :ok
    end
  end

  defp validate_elevated_role(changeset, _role) do
    user_id = Ash.Changeset.get_argument(changeset, :user_id)

    # Allow any user to be owner/organizer
    case Ash.get(Huddlz.Accounts.User, user_id, authorize?: false) do
      {:ok, _user} ->
        :ok

      _ ->
        {:error, field: :user_id, message: "User not found"}
    end
  end
end
