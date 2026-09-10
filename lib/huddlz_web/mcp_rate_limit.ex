defmodule HuddlzWeb.McpRateLimit do
  @moduledoc "Bounds MCP traffic per person and OAuth protocol traffic per IP."
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(mode), do: mode

  @impl true
  def call(conn, mode) do
    {key, limit} = bucket(conn, mode)

    case Huddlz.RateLimit.hit(key, :timer.minutes(1), limit) do
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

  defp bucket(conn, :mcp), do: {{:mcp, Ash.PlugHelpers.get_actor(conn).id}, 120}

  defp bucket(%{request_path: "/oauth/register"} = conn, :oauth),
    do: {{:oauth_registration, conn.remote_ip}, 10}

  defp bucket(conn, :oauth), do: {{:oauth, conn.remote_ip}, 120}
end
