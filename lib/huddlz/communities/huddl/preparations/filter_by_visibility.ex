defmodule Huddlz.Communities.Huddl.Preparations.FilterByVisibility do
  @moduledoc """
  Filters huddls based on visibility rules:
  - Public huddls in public groups are visible to everyone
  - Private huddls are only visible to group members
  - All huddls in private groups are only visible to group members

  This preparation leverages Ash calculations and relationships for a more
  declarative approach to visibility filtering.
  """
  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _opts, %{actor: nil}) do
    # Non-authenticated users can only see public events in public groups
    # Use the is_publicly_visible calculation
    query
    |> Ash.Query.load([:group, :is_publicly_visible])
    |> Ash.Query.filter(is_publicly_visible == true)
  end

  def prepare(query, _opts, %{actor: actor}) do
    # For authenticated users, we can use a more elegant approach
    # leveraging Ash's relationship filtering
    query
    |> Ash.Query.load([:group, :is_publicly_visible])
    |> Ash.Query.filter(
      # Either the huddl is publicly visible
      # Or the actor is a member of the group (using exists on the relationship)
      is_publicly_visible == true or
        exists(group.members, id == ^actor.id)
    )
  end
end
