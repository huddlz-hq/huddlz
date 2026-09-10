defmodule Huddlz.Mcp.SearchContext do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(_input, _opts, context) do
    with {:ok, profile} <- Huddlz.Accounts.get_profile(scope: context) do
      {:ok, Map.put(profile.search_defaults, :now, DateTime.utc_now())}
    end
  end
end
