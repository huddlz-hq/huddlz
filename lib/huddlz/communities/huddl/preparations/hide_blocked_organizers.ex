defmodule Huddlz.Communities.Huddl.Preparations.HideBlockedOrganizers do
  @moduledoc """
  Leaves out huddlz organized by people the actor has blocked. Discovery
  and group lists use it; a personal view such as the huddlz someone is
  going to, or a huddl opened by its link, does not.
  """
  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _opts, %{actor: %{id: actor_id}}) do
    if is_nil(Ash.Query.get_argument(query, :relationship)) do
      Ash.Query.filter(query, not exists(organizer_blocks, blocker_id == ^actor_id))
    else
      query
    end
  end

  def prepare(query, _opts, _context), do: query
end
