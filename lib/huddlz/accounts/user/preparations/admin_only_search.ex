defmodule Huddlz.Accounts.User.Preparations.AdminOnlySearch do
  @moduledoc """
  Filters search results to be empty for non-admin users
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, context) do
    actor = context.actor

    case actor do
      %{role: :admin} ->
        # Admin users can see search results
        query

      _ ->
        # Non-admin users get no results
        Ash.Query.filter(query, false)
    end
  end
end
