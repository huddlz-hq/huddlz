defmodule Huddlz.Communities.Group.Actions.ResolveLocationTimeZone do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    Huddlz.LocationTimeZone.resolve(input.arguments.latitude, input.arguments.longitude)
  end
end
