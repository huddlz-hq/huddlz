import Config
use Envious

# Load environment-specific .env file if it exists
# Production won't have .prod.env - uses system environment variables only
env_file = ".#{config_env()}.env"

if File.exists?(env_file) do
  env_file |> File.read!() |> parse!() |> System.put_env()
end

# =============================================================================
# TzWorld Configuration (all environments)
# =============================================================================
#
# `config/config.exs` also points `:tz_world, :data_dir` at the relative path
# "priv/tz_world_data" so that `mix tz_world.update` (a plain Mix task that
# never loads this runtime config) writes the downloaded polygon data into
# this app's own priv/ dir, keyed off the current working directory (always
# the project root for `mix setup`, CI, and `RUN mix tz_world.update` in the
# Dockerfile builder stage, which uses WORKDIR /app).
#
# The override below is what the running application actually reads (via
# `TzWorld.Backend.Memory`/`TzWorld.GeoData.data_dir/0`). It resolves through
# `Application.app_dir/2`, which is working-directory independent:
#   - In dev/test, `_build/<env>/lib/huddlz/priv` is a symlink back to this
#     project's real `priv/`, so it points at the same files `mix
#     tz_world.update` just wrote.
#   - In a compiled release, `mix release` bundles this project's `priv/`
#     (including `tz_world_data/`, already downloaded before `mix release`
#     runs in the Dockerfile) into `lib/huddlz-<vsn>/priv/`. The release's
#     `bin/server` script `cd`s into `bin/` before starting, so a bare
#     relative "priv/tz_world_data" would resolve to the wrong place;
#     `Application.app_dir/2` finds the real location regardless of CWD.
config :tz_world, :data_dir, Application.app_dir(:huddlz, "priv/tz_world_data")

# Server mode (only parse if set, nil would raise)
if optional("PHX_SERVER") do
  config :huddlz, HuddlzWeb.Endpoint, server: true
end

# =============================================================================
# Database Configuration (all environments)
# =============================================================================

database_url = required!("DATABASE_URL")
pool_size = optional("POOL_SIZE", "8") |> integer!()
ecto_ipv6 = optional("ECTO_IPV6", "false") |> boolean!()

config :huddlz, Huddlz.Repo,
  url: database_url,
  pool_size: pool_size,
  prepare: :unnamed,
  socket_options: if(ecto_ipv6, do: [:inet6], else: [])

# =============================================================================
# Endpoint Configuration (all environments)
# =============================================================================

secret_key_base = required!("SECRET_KEY_BASE")
host = optional("PHX_HOST", "huddlz.com")
port = optional("PORT", "4000") |> integer!()
http_ip = optional("PHX_IP", "::") |> ip!()
scheme = optional("PHX_SCHEME", "https")
check_origin = optional("PHX_CHECK_ORIGIN", "true") |> boolean!()

# In production (https), use standard port 443 (behind reverse proxy).
# In development (http), use the actual server port (e.g., 4000).
url_port = if scheme == "https", do: 443, else: port

config :huddlz, HuddlzWeb.Endpoint,
  url: [host: host, port: url_port, scheme: scheme],
  http: [ip: http_ip, port: port],
  secret_key_base: secret_key_base,
  check_origin: if(check_origin, do: [scheme <> "://" <> host], else: false)

# =============================================================================
# Application Configuration (all environments)
# =============================================================================

config :huddlz,
  token_signing_secret: required!("TOKEN_SIGNING_SECRET")

config :huddlz, :dns_cluster_query, optional("DNS_CLUSTER_QUERY")

# =============================================================================
# Mailer Configuration
# =============================================================================

# Convert module name string to actual module atom
# E.g., "Swoosh.Adapters.Test" -> Swoosh.Adapters.Test
mailer_adapter =
  optional("MAILER_ADAPTER", "Swoosh.Adapters.Mailgun")
  |> String.split(".")
  |> Enum.map(&String.to_atom/1)
  |> Module.concat()

mailer_opts =
  case mailer_adapter do
    Swoosh.Adapters.Mailgun ->
      [
        adapter: mailer_adapter,
        api_key: required!("MAILGUN_API_KEY"),
        domain: required!("MAILGUN_DOMAIN")
      ]

    _ ->
      [adapter: mailer_adapter]
  end

config :huddlz, Huddlz.Mailer, mailer_opts

# =============================================================================
# Storage Configuration (adapter set in compile-time configs)
# =============================================================================

# =============================================================================
# Google Maps Configuration (geocoding + places)
# =============================================================================

google_maps_api_key =
  if config_env() == :prod,
    do: required!("GOOGLE_MAPS_API_KEY"),
    else: optional("GOOGLE_MAPS_API_KEY")

config :huddlz, :google_maps, api_key: google_maps_api_key

if config_env() == :prod do
  required!("AWS_ACCESS_KEY_ID")
  required!("AWS_SECRET_ACCESS_KEY")

  config :huddlz, :storage,
    bucket: required!("BUCKET_NAME"),
    endpoint: required!("AWS_ENDPOINT_URL_S3")

  cors_origins =
    "CORS_ORIGINS"
    |> optional("#{scheme}://#{host}")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))

  config :huddlz, :cors_origins, cors_origins
end
