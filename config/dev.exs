import Config

# Code reloading and watchers - compile-time only
config :huddlz, HuddlzWeb.Endpoint,
  code_reloader: true,
  debug_errors: true,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:huddlz, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:huddlz, ~w(--watch)]}
  ]

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
config :huddlz, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Disable swoosh api client in dev
config :swoosh, :api_client, false

# Database debugging (dev only)
config :huddlz, Huddlz.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Adapters (compile-time - modules must exist at compile)
config :huddlz, :storage, adapter: Huddlz.Storage.Local
