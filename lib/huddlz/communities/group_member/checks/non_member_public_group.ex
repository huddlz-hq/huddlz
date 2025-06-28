defmodule Huddlz.Communities.GroupMember.Checks.NonMemberPublicGroup do
  @moduledoc """
  Check if the actor is a non-member trying to access a public group.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is a non-member accessing a public group"
  end

  @impl true
  def match?(actor, %{subject: %{arguments: %{group_id: group_id}}}, _opts)
      when is_map(actor) and is_binary(group_id) do
    # Allow any logged-in user to access public groups
    with {:ok, group} <- Ash.get(Huddlz.Communities.Group, group_id, actor: actor),
         true <- group.is_public do
      # Check if the user is NOT a member of this group
      not_member?(group_id, actor.id)
    else
      _ -> false
    end
  end

  def match?(_actor, _params, _opts) do
    false
  end

  defp not_member?(group_id, user_id) do
    case Huddlz.Communities.GroupMember
         |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> true
      _ -> false
    end
  end
end
