defmodule CucumberHooks do
  use Cucumber.Hooks

  alias Ecto.Adapters.SQL.Sandbox

  # Hook for @database tag - sets up database sandbox
  before_scenario "@database", context do
    # LiveViews can outlive the scenario process while handling queued messages.
    # Keep their connection alive until ExUnit has stopped supervised children.
    owner = Sandbox.start_owner!(Huddlz.Repo)
    ExUnit.Callbacks.on_exit(fn -> Sandbox.stop_owner(owner) end)

    Mox.stub_with(Huddlz.MockGeocoding, Huddlz.GeocodingStub)
    Mox.stub_with(Huddlz.MockPlaces, Huddlz.PlacesStub)

    {:ok, context}
  end

  # Hook for @conn tag - creates a Phoenix connection
  before_scenario "@conn", context do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})

    {:ok, Map.put(context, :conn, conn)}
  end
end
