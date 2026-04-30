defmodule Huddlz.Communities.Group.Changes.TransferOwnership do
  @moduledoc """
  Implements the side-effects of `Group.:transfer_ownership`:

    * Sets `owner_id` to the new owner.
    * Demotes the previous owner's GroupMember row to `:organizer`.
    * Promotes the new owner's GroupMember row to `:owner`, creating the
      membership if the new owner is not already in the group.

  Runs as a single `after_action` hook so it lands inside the same Ash
  transaction as the owner_id update.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  @impl true
  def change(changeset, _opts, _context) do
    new_owner_id = Ash.Changeset.get_argument(changeset, :new_owner_id)
    previous_owner_id = changeset.data.owner_id

    changeset
    |> Ash.Changeset.force_change_attribute(:owner_id, new_owner_id)
    |> Ash.Changeset.after_action(fn _cs, group ->
      with :ok <- demote(group.id, previous_owner_id),
           :ok <- promote(group.id, new_owner_id) do
        {:ok, group}
      end
    end)
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
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
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
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      membership ->
        membership
        |> Ash.Changeset.for_update(:set_role, %{role: :owner})
        |> Ash.update(authorize?: false)
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp fetch_membership(group_id, user_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id)
    |> Ash.read_one!(authorize?: false)
  end
end
