defmodule Huddlz.Communities.GroupInvitation.Checks.InviteeIsNotMember do
  @moduledoc false

  use Ash.Resource.Validation

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    group_id = Ash.Changeset.get_argument(changeset, :group_id)
    invitee_id = Ash.Changeset.get_argument(changeset, :invitee_id)

    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^invitee_id)
    |> Ash.exists?(authorize?: false)
    |> case do
      true -> {:error, field: :invitee_id, message: "is already a member of this group"}
      false -> :ok
    end
  end
end
