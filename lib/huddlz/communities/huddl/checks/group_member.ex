defmodule Huddlz.Communities.Huddl.Checks.GroupMember do
  @moduledoc """
  Check if the actor is a member of the group for the huddl.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.GroupMember
  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is a member of the group"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  @impl true
  def match?(actor, context, _opts) do
    group_id = get_group_id(context)

    if group_id do
      check_membership(actor, group_id)
    else
      # For queries without a specific record, we allow and let query filters handle it
      match?(:query, context.type)
    end
  end

  # Extract group_id from various contexts
  defp get_group_id(%{changeset: %{data: %{group_id: group_id}}}), do: group_id
  defp get_group_id(%{record: %{group_id: group_id}}), do: group_id
  defp get_group_id(_), do: nil

  # Check if the actor is a member of the group
  defp check_membership(%{id: user_id}, group_id) when is_binary(group_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id)
    |> Ash.exists?(authorize?: false)
  end

  defp check_membership(_actor, _group_id), do: false
end
