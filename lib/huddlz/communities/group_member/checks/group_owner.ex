defmodule Huddlz.Communities.GroupMember.Checks.GroupOwner do
  @moduledoc """
  Custom Ash policy check to authorize :add_member if the actor is the owner of the group.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Huddlz.Communities.Group

  @impl true
  def describe(_opts) do
    "actor is the owner of the group"
  end

  @impl true
  def match?(actor, %{subject: %{arguments: %{group_id: group_id}}}, _opts)
      when is_map(actor) and is_binary(group_id) do
    case Ash.get(Group, group_id, actor: actor) do
      {:ok, %Huddlz.Communities.Group{owner_id: owner_id}} ->
        actor.id == owner_id

      _ ->
        false
    end
  end

  def match?(_actor, _params, _opts) do
    false
  end
end
