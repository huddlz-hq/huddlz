defmodule Huddlz.Communities.Group.Actions.Overview do
  @moduledoc """
  Runs the group's `:overview` action: the organizer overview figures for
  a period. Authorization happens on the action (owner or organizer of
  the named group); the figures themselves are derived by
  `Huddlz.Communities.GroupStats`.
  """
  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Query.NotFound
  alias Huddlz.Communities.{Group, GroupStats}

  require Ash.Query

  @impl true
  def run(input, _opts, context) do
    group_id = Ash.ActionInput.get_argument(input, :group_id)
    period = input |> Ash.ActionInput.get_argument(:period) |> GroupStats.parse_period()

    # Archived groups still have an overview for their organizers.
    Group
    |> Ash.Query.for_read(:read_with_archived)
    |> Ash.Query.filter(id == ^group_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Group{} = group} -> {:ok, GroupStats.compute(group, period, context.actor)}
      {:ok, nil} -> {:error, NotFound.exception(resource: Group)}
      {:error, error} -> {:error, error}
    end
  end
end
