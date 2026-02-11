ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

# Set up global geocoding stub so all tests can create groups/huddlz
# without needing explicit Mox expectations. Individual tests can override
# with Mox.expect/3 or Mox.stub/3.
Mox.stub_with(Huddlz.MockGeocoding, Huddlz.GeocodingStub)

Cucumber.compile_features!()
