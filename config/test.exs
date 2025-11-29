import Config
config :huddlz, Oban, testing: :manual
config :huddlz, token_signing_secret: "B/l8TS6gx/jZednXDgVLAka5u5vIqk22"
config :bcrypt_elixir, log_rounds: 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :huddlz, Huddlz.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "huddlz_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :huddlz, HuddlzWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "yR+dqFnLawZ7U9W6jp18CyH+bPO6t108hfKDstiG+2Oyl94zmTA+LUXXVu6gA5Q5",
  server: false

# In test we don't send emails
config :huddlz, Huddlz.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

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

# Local file storage for tests
config :huddlz, :storage, adapter: Huddlz.Storage.Local
