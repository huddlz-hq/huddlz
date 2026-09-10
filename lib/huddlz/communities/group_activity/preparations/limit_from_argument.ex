defmodule Huddlz.Communities.GroupActivity.Preparations.LimitFromArgument do
  @moduledoc false

  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.limit(query, Ash.Query.get_argument(query, :limit))
  end
end
