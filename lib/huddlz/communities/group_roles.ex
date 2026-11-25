defmodule Huddlz.Communities.GroupRoles do
  @moduledoc """
  Looks up the current group roles used by single-target policy checks.
  Ownership comes from the group. Waitlist access uses the membership role
  after the caller has established that the actor can read the huddl.
  """

  alias Huddlz.Communities.{Group, GroupMember}

  require Ash.Query

  def owns_or_organizes?(actor, group_id, read_action \\ :read)

  def owns_or_organizes?(%{id: user_id} = actor, group_id, read_action)
      when not is_nil(user_id) and not is_nil(group_id) do
    case Ash.get(Group, group_id, action: read_action, authorize?: false) do
      {:ok, %Group{owner_id: ^user_id}} -> true
      {:ok, %Group{id: id}} -> has_membership_role?(actor, id, [:organizer])
      _ -> false
    end
  end

  def owns_or_organizes?(_actor, _group_id, _read_action), do: false

  def has_membership_role?(%{id: user_id}, group_id, roles) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id and role in ^roles)
    |> Ash.exists?(authorize?: false)
  end
end
