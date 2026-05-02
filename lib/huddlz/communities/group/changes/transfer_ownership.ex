defmodule Huddlz.Communities.Group.Changes.TransferOwnership do
  @moduledoc """
  Implements the side-effects of `Group.:transfer_ownership`:

    * Sets `owner_id` to the new owner.
    * Demotes the previous owner's GroupMember row to `:organizer`.
    * Promotes the new owner's GroupMember row to `:owner`, creating the
      membership if the new owner is not already in the group.
    * Enqueues B7 notifications to both the previous and new owners.

  Runs as a single `after_action` hook so it lands inside the same Ash
  transaction as the owner_id update.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    new_owner_id = Ash.Changeset.get_argument(changeset, :new_owner_id)
    previous_owner_id = changeset.data.owner_id

    changeset
    |> Ash.Changeset.force_change_attribute(:owner_id, new_owner_id)
    |> Ash.Changeset.after_action(fn _cs, group ->
      with :ok <- demote(group.id, previous_owner_id),
           :ok <- promote(group.id, new_owner_id) do
        notify(group, previous_owner_id, new_owner_id)
        {:ok, group}
      end
    end)
  end

  defp notify(group, previous_owner_id, new_owner_id) do
    previous_owner =
      case Ash.get(User, previous_owner_id, authorize?: false) do
        {:ok, %User{} = u} -> u
        _ -> nil
      end

    new_owner =
      case Ash.get(User, new_owner_id, authorize?: false) do
        {:ok, %User{} = u} -> u
        _ -> nil
      end

    base = %{
      "group_id" => group.id,
      "group_name" => to_string(group.name),
      "group_slug" => group.slug,
      "previous_owner_display_name" => previous_owner && previous_owner.display_name,
      "new_owner_display_name" => new_owner && new_owner.display_name
    }

    if previous_owner do
      Notifications.deliver(
        previous_owner,
        :group_ownership_transferred,
        Map.put(base, "role", "previous_owner")
      )
    end

    if new_owner do
      Notifications.deliver(
        new_owner,
        :group_ownership_transferred,
        Map.put(base, "role", "new_owner")
      )
    end
  end

  defp demote(_group_id, nil), do: :ok

  defp demote(group_id, user_id) do
    case fetch_membership(group_id, user_id) do
      nil ->
        :ok

      membership ->
        membership
        |> Ash.Changeset.for_update(:set_role, %{role: :organizer})
        |> Ash.update(authorize?: false)
        |> ok_or_error()
    end
  end

  defp promote(group_id, user_id) do
    case fetch_membership(group_id, user_id) do
      nil ->
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group_id,
          user_id: user_id,
          role: "owner"
        })
        |> Ash.create(authorize?: false)
        |> ok_or_error()

      membership ->
        membership
        |> Ash.Changeset.for_update(:set_role, %{role: :owner})
        |> Ash.update(authorize?: false)
        |> ok_or_error()
    end
  end

  defp ok_or_error({:ok, _}), do: :ok
  defp ok_or_error({:error, reason}), do: {:error, reason}

  defp fetch_membership(group_id, user_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id)
    |> Ash.read_one!(authorize?: false)
  end
end
