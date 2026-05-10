defmodule Huddlz.Communities.Group.Preparations.ApplyMyGroupsFilter do
  @moduledoc """
  Filters a Group read down to the actor's relationship with the result rows.

  Reads the `:relationship` argument (one of `:all`, `:hosting`, `:joined`):

    * `:hosting` — the actor owns the group.
    * `:joined`  — the actor is a member but not the owner.
    * `:all`     — either of the above.

  Sorting is delegated to `ApplyTrigramSearch` (alphabetical by `name` when
  no `:search` arg is present), so the SQL ordering matches the other group
  listings.
  """

  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    actor_id = context.actor && context.actor.id

    if is_nil(actor_id) do
      Ash.Query.filter(query, false)
    else
      relationship = Ash.Query.get_argument(query, :relationship) || :all
      apply_filter(query, relationship, actor_id)
    end
  end

  defp apply_filter(query, :hosting, actor_id),
    do: Ash.Query.filter(query, owner_id == ^actor_id)

  defp apply_filter(query, :joined, actor_id) do
    Ash.Query.filter(
      query,
      owner_id != ^actor_id and
        exists(group_members, user_id == ^actor_id)
    )
  end

  defp apply_filter(query, :all, actor_id) do
    Ash.Query.filter(
      query,
      owner_id == ^actor_id or
        exists(group_members, user_id == ^actor_id)
    )
  end
end
