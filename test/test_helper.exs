# Each database test owns a connection until its sandbox is stopped. The
# scheduler-based default can exceed the pool on machines with many cores.
max_cases = min(System.schedulers_online() * 2, Keyword.fetch!(Huddlz.Repo.config(), :pool_size))
ExUnit.start(capture_log: true, max_cases: max_cases)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

# Set up global geocoding stub so all tests can create groups/huddlz
# without needing explicit Mox expectations. Individual tests can override
# with Mox.expect/3 or Mox.stub/3.
Mox.stub_with(Huddlz.MockGeocoding, Huddlz.GeocodingStub)
