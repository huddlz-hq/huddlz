ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

# Start Wallaby for browser testing
{:ok, _} = Application.ensure_all_started(:wallaby)

# Configure Wallaby base URL
Application.put_env(:wallaby, :base_url, HuddlzWeb.Endpoint.url())
