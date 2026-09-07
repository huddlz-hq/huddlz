defmodule Huddlz.Communities.GroupInvitation.Changes.ResolveRecipient do
  @moduledoc false
  use Ash.Resource.Change

  alias Huddlz.Accounts.User

  @impl true
  def change(changeset, _opts, _context) do
    case recipient(changeset) do
      {:ok, user} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:invitee_id, user && user.id)
        |> Ash.Changeset.force_change_attribute(:email, email(changeset, user))

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  defp recipient(changeset) do
    case Ash.Changeset.get_argument(changeset, :invitee_id) do
      nil ->
        User
        |> Ash.Query.for_read(:get_by_email, %{
          email: Ash.Changeset.get_argument(changeset, :email)
        })
        |> Ash.read_one(authorize?: false)

      id ->
        Ash.get(User, id, authorize?: false)
    end
  end

  defp email(changeset, nil), do: Ash.Changeset.get_argument(changeset, :email)
  defp email(_changeset, user), do: user.email
end
