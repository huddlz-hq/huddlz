defmodule Huddlz.Communities.Group.Checks.OrganizesGroupArgument do
  @moduledoc """
  Authorizes a generic action whose `group_id` argument names a group the
  actor owns or organizes. Generic actions have no record to write an
  expression policy against, so the lookup happens here.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.{Group, GroupMember}

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor owns or organizes the group named by group_id"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{action_input: %Ash.ActionInput{} = input}, _opts) do
    input
    |> Ash.ActionInput.get_argument(:group_id)
    |> organizes?(actor)
  end

  def match?(_actor, _context, _opts), do: false

  defp organizes?(nil, _actor), do: false

  # Archived groups keep their organizers, so read through the archive-aware action.
  defp organizes?(group_id, actor) do
    Group
    |> Ash.Query.for_read(:read_with_archived)
    |> Ash.Query.filter(id == ^group_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Group{owner_id: owner_id}} when owner_id == actor.id ->
        true

      {:ok, %Group{} = group} ->
        GroupMember
        |> Ash.Query.filter(group_id == ^group.id and user_id == ^actor.id and role == :organizer)
        |> Ash.exists?(authorize?: false)

      _ ->
        false
    end
  end
end
