defmodule Huddlz.Communities.Huddl.Preparations.FilterByVisibility do
  @moduledoc """
  Filters huddls based on visibility rules:
  - Public huddls in public groups are visible to everyone
  - Private huddls are only visible to group members
  - All huddls in private groups are only visible to group members
  """
  use Ash.Resource.Preparation

  alias Huddlz.Communities.GroupMember
  require Ash.Query

  def prepare(query, _opts, %{actor: nil}) do
    # Non-authenticated users can only see public events in public groups
    query
    |> Ash.Query.load(:group)
    |> Ash.Query.filter(is_private == false and group.is_public == true)
  end

  def prepare(query, _opts, %{actor: actor}) do
    # Get groups where the user is a member
    member_group_ids =
      GroupMember
      |> Ash.Query.for_read(:read, %{}, actor: actor, authorize?: false)
      |> Ash.Query.filter(user_id: actor.id)
      |> Ash.read!(actor: actor, authorize?: false)
      |> Enum.map(& &1.group_id)

    # Load the group relationship
    query = Ash.Query.load(query, :group)

    # Users can see:
    # 1. Public events in public groups
    # 2. All events in groups they're members of
    if Enum.empty?(member_group_ids) do
      # User is not a member of any groups, can only see public events
      query
      |> Ash.Query.filter(is_private == false and group.is_public == true)
    else
      query
      |> Ash.Query.filter(
        group_id in ^member_group_ids or
          (is_private == false and group.is_public == true)
      )
    end
  end
end
