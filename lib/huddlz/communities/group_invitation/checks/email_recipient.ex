defmodule Huddlz.Communities.GroupInvitation.Checks.EmailRecipient do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupInvitation.EmailToken

  @impl true
  def describe(_opts), do: "actor owns the invitation email and its signed link"

  @impl true
  def match?(%{id: user_id}, %{subject: changeset}, _opts) do
    with {:ok, id} <- EmailToken.verify(Ash.Changeset.get_argument(changeset, :token)),
         true <- id == changeset.data.id,
         {:ok, user} <- Ash.get(User, user_id, authorize?: false) do
      is_nil(changeset.data.invitee_id) and
        Ash.CiString.compare(user.email, changeset.data.email) == :eq
    else
      _ -> false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
