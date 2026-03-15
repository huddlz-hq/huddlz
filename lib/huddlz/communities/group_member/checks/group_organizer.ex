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
  def match?(actor, %{subject: %{arguments: %{group_id: group_id}}}, _opts)
      when is_map(actor) and is_binary(group_id) do
    GroupMember
    |> Ash.Query.filter(group_id: group_id, user_id: actor.id, role: :organizer)
    |> Ash.exists?(authorize?: false)
  end

  def match?(_actor, _params, _opts), do: false
end
