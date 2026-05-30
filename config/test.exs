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

# Rate limiting is off by default in test so the suite isn't throttled; the
# rate-limit test files enable it for their own scope. Limits are small so those
# tests trip the limit in a few calls.
config :huddlz, :rate_limit_enabled, false

config :huddlz, :auth_rate_limits,
  sign_in: [limit: 5, per: :timer.minutes(1)],
  register: [limit: 5, per: :timer.minutes(1)],
  password_reset: [limit: 5, per: :timer.hours(1)]

# Configure PhoenixTest
config :phoenix_test, :endpoint, HuddlzWeb.Endpoint

# Disable swoosh api client in test
config :swoosh, :api_client, false

# Adapters (compile-time)
config :huddlz, :storage, adapter: Huddlz.Storage.Local
config :huddlz, :geocoding, adapter: Huddlz.MockGeocoding
config :huddlz, :places, adapter: Huddlz.MockPlaces
config :huddlz, geocoding_req_plug: {Req.Test, Huddlz.Geocoding.Google}
config :huddlz, places_req_plug: {Req.Test, Huddlz.Places.Google}
# Real Google adapters read this key for request headers; the configured
# MockGeocoding/MockPlaces adapters mean live code never sends it, but the
# *_req_plug-backed adapter tests need a non-nil value.
config :huddlz, :google_maps, api_key: "test-google-maps-key"
config :huddlz, Huddlz.Repo, pool: Ecto.Adapters.SQL.Sandbox
config :huddlz, :sql_sandbox?, true

# CORS — allow all origins so tests don't have to configure them
config :huddlz, :cors_origins, :all
