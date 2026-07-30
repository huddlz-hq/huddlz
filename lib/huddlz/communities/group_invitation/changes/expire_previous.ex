defmodule Huddlz.Communities.GroupInvitation.Changes.ExpirePrevious do
  @moduledoc false

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation

  @impl true
  def change(changeset, _opts, _context) do
    group_id = Ash.Changeset.get_argument(changeset, :group_id)
    invitee_id = Ash.Changeset.get_argument(changeset, :invitee_id)

    Ash.Changeset.before_action(changeset, fn changeset ->
      GroupInvitation
      |> Ash.Query.filter(
        group_id == ^group_id and invitee_id == ^invitee_id and status == :pending and
          expires_at <= now()
      )
      |> Ash.read!(authorize?: false)
      |> Enum.each(&Communities.expire_group_invitation!(&1, authorize?: false))

      changeset
    end)
  end
end
