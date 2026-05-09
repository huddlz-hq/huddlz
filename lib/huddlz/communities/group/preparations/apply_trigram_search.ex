defmodule Huddlz.Communities.Group.Preparations.ApplyTrigramSearch do
  @moduledoc """
  Reads the `:query` argument and, when present, applies a trigram-similarity
  filter on `name`/`description` plus a relevance-then-name sort. With a nil
  query, falls back to alphabetical sort by name.

  Used by Group read actions that share the same search semantics
  (`:search`, `:get_by_owner`, `:get_joined`) so that listing endpoints
  behave consistently.
  """

  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :search) do
      nil ->
        Ash.Query.sort(query, name: :asc)

      q ->
        query
        |> Ash.Query.filter(
          trigram_similarity(name, ^q) > 0.1 or
            trigram_similarity(description, ^q) > 0.1
        )
        |> Ash.Query.load(search_relevance: [query: q])
        |> Ash.Query.sort(search_relevance: {%{query: q}, :desc}, name: :asc)
    end
  end
end
