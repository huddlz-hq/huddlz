defmodule Huddlz.Communities.Huddl.Checks.GroupMember do
  @moduledoc """
  Check if the actor is a member of the group for the huddl.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.GroupMember
  require Ash.Query

  def describe(_opts) do
    "actor is a member of the group"
  end

  def match?(nil, _context, _opts), do: false

  def match?(_actor, %{resource: _resource, query: %Ash.Query{}}, _opts) do
    # For queries, we'll handle this through preparations
    true
  end

  def match?(actor, %{resource: _resource, changeset: %Ash.Changeset{data: huddl}}, _opts) do
    check_membership(actor, huddl.group_id)
  end

  def match?(actor, %{resource: _resource} = context, _opts) do
    # Try to get the huddl
    case Map.get(context, :record) do
      %{group_id: group_id} ->
        check_membership(actor, group_id)

      _ ->
        false
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp check_membership(actor, group_id) when is_binary(group_id) do
    GroupMember
    |> Ash.Query.for_read(:read, %{}, authorize?: false)
    |> Ash.Query.filter(group_id: group_id, user_id: actor.id)
    |> Ash.exists?()
  end

  defp check_membership(_actor, _group_id), do: false
end
