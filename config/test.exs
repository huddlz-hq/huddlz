import Config

config :huddlz, Oban, testing: :manual
config :bcrypt_elixir, log_rounds: 1

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :ash, :disable_async?, true
config :ash, :missed_notifications, :ignore

# Set environment to test for test-specific behavior
config :huddlz, env: :test

# Configure PhoenixTest
config :phoenix_test, :endpoint, HuddlzWeb.Endpoint

# Disable swoosh api client in test
config :swoosh, :api_client, false

# Adapters (compile-time)
config :huddlz, :storage, adapter: Huddlz.Storage.Local
config :huddlz, Huddlz.Repo, pool: Ecto.Adapters.SQL.Sandbox

# Use mock for geocoding service in tests
config :huddlz, :geocoding_service, Huddlz.Geocoding.Mock
