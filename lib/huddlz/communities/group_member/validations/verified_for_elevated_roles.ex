defmodule Huddlz.Communities.GroupMember.Validations.VerifiedForElevatedRoles do
  @moduledoc """
  Validates that only verified users can be assigned as owner or organizer.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    role = Ash.Changeset.get_attribute(changeset, :role)

    if role in [:owner, :organizer] do
      user_id = Ash.Changeset.get_argument(changeset, :user_id)

      case Ash.get(Huddlz.Accounts.User, user_id, authorize?: false) do
        {:ok, user} ->
          if user.role in [:verified, :admin] do
            :ok
          else
            {:error, field: :role, message: "Only verified users can be assigned as #{role}"}
          end

        _ ->
          {:error, field: :user_id, message: "User not found"}
      end
    else
      :ok
    end
  end
end
