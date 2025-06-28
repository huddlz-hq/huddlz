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
    # Check if the actor is a member of the group

    query =
      GroupMember
      |> Ash.Query.filter(group_id: group_id, user_id: actor.id)
      |> Ash.Query.limit(1)

    case Ash.read(query, authorize?: false) do
      {:ok, [%GroupMember{}]} -> true
      _ -> false
    end
  end

  def match?(_actor, _params, _opts), do: false
end
