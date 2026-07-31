defmodule Huddlz.Communities.Huddl.Preparations.FilterByVisibility do
  @moduledoc """
  Filters huddlz based on visibility and lifecycle rules:
  - Published and completed public huddlz in public groups are visible to everyone
  - Published and completed private huddlz are only visible to group members
  - Drafts are visible only to their organizers
  - Cancelled huddlz remain visible to organizers and people with RSVP history

  This preparation leverages Ash calculations and relationships for a more
  declarative approach to visibility filtering.
  """
  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _opts, %{actor: nil}) do
    query
    |> Ash.Query.load([:group, :is_publicly_visible])
    |> Ash.Query.filter(
      lifecycle_state in [:published, :completed] and is_publicly_visible == true
    )
  end

  def prepare(query, _opts, %{actor: %{role: :admin}}) do
    Ash.Query.load(query, [:group, :is_publicly_visible])
  end

  # One declarative database predicate is safer here than merging separately
  # fetched lifecycle result sets, and keeps every visibility branch in SQL.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def prepare(query, _opts, %{actor: actor}) do
    query
    |> Ash.Query.load([:group, :is_publicly_visible])
    |> Ash.Query.filter(
      (lifecycle_state in [:published, :completed] and
         (is_publicly_visible == true or exists(group.members, id == ^actor.id))) or
        (lifecycle_state in [:draft, :cancelled] and
           (creator_id == ^actor.id or group.owner_id == ^actor.id or
              exists(
                group.group_members,
                user_id == ^actor.id and role == :organizer
              ))) or
        (lifecycle_state == :cancelled and exists(attendees, user_id == ^actor.id))
    )
  end
end
