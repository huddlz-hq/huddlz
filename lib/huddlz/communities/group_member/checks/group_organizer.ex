defmodule Huddlz.Communities.GroupMember.Checks.GroupOrganizer do
  @moduledoc """
  Ash policy check: passes if the actor is an organizer of the group.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  @impl true
  def describe(_opts), do: "actor is an organizer of the group"

  @impl true
  def match?(actor, %{group_id: group_id}, _opts)
      when not is_nil(actor) and not is_nil(group_id) do
    query =
      GroupMember
      |> Ash.Query.filter(group_id: group_id, user_id: actor.id, role: :organizer)
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: actor) do
      {:ok, [%GroupMember{}]} -> true
      _ -> false
    end
  end

  def match?(_actor, _params, _opts), do: false
end
