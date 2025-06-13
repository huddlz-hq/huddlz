defmodule Huddlz.Communities.GroupMember.Checks.GroupMember do
  @moduledoc """
  Ash policy check: passes if the actor is a member of the group.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  @impl true
  def describe(_opts), do: "actor is a member of the group"

  @impl true
  def match?(actor, %{subject: %{arguments: %{group_id: group_id}}}, _opts)
      when not is_nil(actor) and not is_nil(group_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^actor.id)
    |> Ash.exists?(actor: actor)
  end

  def match?(_actor, _params, _opts) do
    false
  end
end
