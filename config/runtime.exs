import Config
use Envious

# Load environment-specific .env file if it exists
# Production won't have .prod.env - uses system environment variables only
env_file = ".#{config_env()}.env"

if File.exists?(env_file) do
  env_file |> File.read!() |> parse!() |> System.put_env()
end

# Server mode (only parse if set, nil would raise)
if phx_server = optional("PHX_SERVER") do
  config :huddlz, HuddlzWeb.Endpoint, server: true
end

# =============================================================================
# Database Configuration (all environments)
# =============================================================================

database_url = required!("DATABASE_URL")
pool_size = optional("POOL_SIZE", "10") |> integer!()
ecto_ipv6 = optional("ECTO_IPV6", "false") |> boolean!()
ecto_ssl = optional("ECTO_SSL", "true") |> boolean!()

config :huddlz, Huddlz.Repo,
  url: database_url,
  pool_size: pool_size,
  socket_options: if(ecto_ipv6, do: [:inet6], else: []),
  ssl: if(ecto_ssl, do: [verify: :verify_none], else: false)

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

if config_env() == :prod do
  required!("AWS_ACCESS_KEY_ID")
  required!("AWS_SECRET_ACCESS_KEY")

  config :huddlz, :storage,
    bucket: required!("BUCKET_NAME"),
    endpoint: required!("AWS_ENDPOINT_URL_S3")
end
