defmodule Huddlz.Communities.GroupMember.Checks.GroupVerifiedMember do
  @moduledoc """
  Ash policy check: passes if the actor is a verified member of the group.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  @impl true
  def describe(_opts), do: "actor is a verified member of the group"

  @impl true
  def match?(actor, %{subject: %{arguments: %{group_id: group_id}}}, _opts)
      when not is_nil(actor) and not is_nil(group_id) do
    # Check if the actor is a member of the group and is verified

    query =
      GroupMember
      |> Ash.Query.filter(group_id: group_id, user_id: actor.id)
      |> Ash.Query.limit(1)

    case Ash.read(query, authorize?: false) do
      {:ok, [%GroupMember{}]} ->
        # Check if the actor (user) is verified
        case Map.get(actor, :role) do
          :verified -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  def match?(_actor, _params, _opts), do: false
end
