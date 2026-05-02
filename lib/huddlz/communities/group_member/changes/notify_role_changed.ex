defmodule Huddlz.Communities.GroupMember.Changes.NotifyRoleChanged do
  @moduledoc """
  Enqueues B4 (group_role_changed) when a member's role changes via
  :change_role. The recipient is the affected member. No email is sent
  if the role didn't actually change.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    previous_role = changeset.data.role

    Ash.Changeset.after_action(changeset, fn _cs, member ->
      if previous_role != member.role do
        deliver(member, previous_role)
      end

      {:ok, member}
    end)
  end

  defp deliver(member, previous_role) do
    with {:ok, user} <- Ash.get(User, member.user_id, authorize?: false),
         {:ok, group} <- Ash.get(Group, member.group_id, authorize?: false) do
      Notifications.deliver(user, :group_role_changed, %{
        "group_id" => group.id,
        "group_name" => to_string(group.name),
        "group_slug" => group.slug,
        "previous_role" => to_string(previous_role),
        "new_role" => to_string(member.role)
      })
    end
  end
end
