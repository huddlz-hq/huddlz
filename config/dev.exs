import Config

# Configure your database
config :huddlz, Huddlz.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "huddlz_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :huddlz, HuddlzWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "cIa6Yvo2TG1NbWsQblHGSD8zNFJolWBjHqrlVoQWPBQ9MlW/bu1OampLzLADetP0",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:huddlz, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:huddlz, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :huddlz, HuddlzWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/huddlz_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :huddlz, dev_routes: true, token_signing_secret: "/A60LYcpcenN52Sishm+PjFjYIb6dR7n"

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
# To use SendGrid in development, comment out the line below and set SENDGRID_API_KEY
config :swoosh, :api_client, false

# Optional: Enable SendGrid in development
# if sendgrid_api_key = System.get_env("SENDGRID_API_KEY") do
#   config :huddlz, Huddlz.Mailer,
#     adapter: Swoosh.Adapters.Sendgrid,
#     api_key: sendgrid_api_key
#
#   config :swoosh, :api_client, Swoosh.ApiClient.Req
# end
