defmodule HuddlzWeb.McpRateLimit do
  @moduledoc "Bounds MCP traffic to 120 requests a minute per person."
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    key = {:mcp, Ash.PlugHelpers.get_actor(conn).id}

    case Huddlz.RateLimit.hit(key, :timer.minutes(1), 120) do
      {:allow, _} ->
        conn

      {:deny, retry_ms} ->
        conn
        |> put_resp_header("retry-after", to_string(max(1, ceil(retry_ms / 1000))))
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_content_type("application/json")
        |> send_resp(
          429,
          Jason.encode!(%{
            error: "rate_limited",
            message: "Wait for Retry-After before retrying."
          })
        )
        |> halt()
    end
  end
end
