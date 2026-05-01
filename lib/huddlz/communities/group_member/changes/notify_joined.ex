defmodule Huddlz.Communities.GroupMember.Changes.NotifyJoined do
  @moduledoc """
  Enqueues B1 (group_member_joined) notifications when a user joins a
  public group via :join_group. Recipients are the group's owner and
  organizers, deduplicated and with the actor (the joining user)
  excluded.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, member ->
      deliver(member)
      {:ok, member}
    end)
  end

  defp deliver(%GroupMember{group_id: group_id, user_id: joiner_id}) do
    with {:ok, group} <- Ash.get(Group, group_id, authorize?: false),
         {:ok, joiner} <- Ash.get(User, joiner_id, authorize?: false) do
      payload = %{
        "group_id" => group.id,
        "group_name" => to_string(group.name),
        "group_slug" => group.slug,
        "joiner_display_name" => joiner.display_name
      }

      group_id
      |> RecipientHelpers.group_organizer_user_ids(exclude: joiner_id)
      |> RecipientHelpers.deliver_each(:group_member_joined, payload)
    end
  end
end
