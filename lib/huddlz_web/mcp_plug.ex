defmodule HuddlzWeb.MCPPlug do
  @moduledoc """
  Authenticated, rate-limited edge for the huddlz Streamable HTTP MCP server.

  This plug runs before `Plug.Parsers` so the MCP transport can read the raw
  JSON-RPC request body. Public discovery is allowed without a bearer token;
  authenticated tools receive the actor established by the existing JWT/API
  key plugs.
  """

  @behaviour Plug

  alias AshAuthentication.Phoenix.Plug, as: AuthenticationPlug
  alias AshAuthentication.Plug.Helpers, as: AuthenticationHelpers
  alias Huddlz.Accounts.User
  alias Huddlz.MCP.Transport
  alias Huddlz.RateLimit
  alias HuddlzWeb.ApiAuth
  alias MCP.Transport.StreamableHTTP.Plug, as: StreamableHTTPPlug

  @mcp_path ["mcp"]

  @impl Plug
  def init(_opts) do
    %{api_auth: ApiAuth.init(resource: User, required?: false)}
  end

  @impl Plug
  def call(%Plug.Conn{path_info: @mcp_path} = conn, config) do
    config = Map.merge(config, Transport.config())

    case validate_origin(conn) do
      :ok ->
        conn = authenticate(conn, config.api_auth)

        if conn.halted do
          conn
        else
          call_transport(conn, config)
        end

      {:error, :invalid_origin} ->
        json_rpc_error(conn, 403, -32_600, "Forbidden", "Origin is not allowed")
    end
  end

  def call(conn, _config), do: conn

  defp call_transport(conn, config) do
    with :ok <- enforce_rate_limit(conn),
         :ok <- authorize_session(conn, config.sessions) do
      conn
      |> prepare_for_transport()
      |> StreamableHTTPPlug.call(config.transport)
      |> remember_session(conn, config.sessions)
      |> Plug.Conn.halt()
    else
      {:error, {:rate_limited, retry_after}} ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", Integer.to_string(retry_after))
        |> json_rpc_error(429, -32_000, "Too many requests", "Try again later")

      {:error, :session_principal_mismatch} ->
        json_rpc_error(
          conn,
          403,
          -32_600,
          "Forbidden",
          "This MCP session belongs to a different principal"
        )
    end
  end

  defp authenticate(conn, api_auth) do
    conn
    |> AuthenticationPlug.load_from_bearer(otp_app: :huddlz)
    |> AuthenticationHelpers.set_actor(:user)
    |> ApiAuth.call(api_auth)
    |> AuthenticationHelpers.set_actor(:user)
  end

  defp validate_origin(conn) do
    case Plug.Conn.get_req_header(conn, "origin") do
      [] ->
        :ok

      origins ->
        if Enum.all?(origins, &same_host?(&1, conn.host)) do
          :ok
        else
          {:error, :invalid_origin}
        end
    end
  end

  defp same_host?(origin, request_host) do
    case URI.parse(origin) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) ->
        String.downcase(host) == String.downcase(request_host)

      _ ->
        false
    end
  end

  defp enforce_rate_limit(conn) do
    {bucket, limit} =
      case Ash.PlugHelpers.get_actor(conn) do
        %User{id: id} -> {"user:" <> id, mcp_rate_limit(:authenticated)}
        _ -> {"ip:" <> remote_ip(conn.remote_ip), mcp_rate_limit(:anonymous)}
      end

    per = mcp_rate_limit(:per)

    case RateLimit.hit("mcp:" <> bucket, per, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after_ms} -> {:error, {:rate_limited, ceil(retry_after_ms / 1000)}}
    end
  end

  defp mcp_rate_limit(key) do
    :huddlz
    |> Application.fetch_env!(:mcp_rate_limits)
    |> Keyword.fetch!(key)
  end

  defp remote_ip(ip) do
    case :inet.ntoa(ip) do
      address when is_list(address) -> List.to_string(address)
      _ -> "unknown"
    end
  end

  defp authorize_session(conn, sessions) do
    case Plug.Conn.get_req_header(conn, "mcp-session-id") do
      [] ->
        :ok

      [session_id | _] ->
        case :ets.lookup(sessions, session_id) do
          [] -> :ok
          [{^session_id, principal}] -> compare_principal(principal, principal(conn))
        end
    end
  end

  defp compare_principal(principal, principal), do: :ok
  defp compare_principal(_expected, _actual), do: {:error, :session_principal_mismatch}

  defp principal(conn) do
    case Ash.PlugHelpers.get_actor(conn) do
      %User{id: id} -> {:user, id}
      _ -> :anonymous
    end
  end

  # Version 1.1 of the SDK intentionally permits only localhost Origin values.
  # We perform the remote-safe same-host Origin validation above, then remove
  # the already-validated Origin before the transport's final local-only guard.
  # Plug stores Host in `conn.host`, not as a mutable request header.
  defp prepare_for_transport(conn) do
    Plug.Conn.delete_req_header(conn, "origin")
  end

  defp remember_session(response_conn, request_conn, sessions) do
    case Plug.Conn.get_resp_header(response_conn, "mcp-session-id") do
      [session_id | _] ->
        :ets.insert(sessions, {session_id, principal(request_conn)})

      [] ->
        if request_conn.method == "DELETE" do
          forget_session(request_conn, sessions)
        end
    end

    response_conn
  end

  defp forget_session(conn, sessions) do
    case Plug.Conn.get_req_header(conn, "mcp-session-id") do
      [session_id | _] -> :ets.delete(sessions, session_id)
      [] -> :ok
    end
  end

  defp json_rpc_error(conn, status, code, message, data) do
    body =
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "error" => %{"code" => code, "message" => message, "data" => data}
      })

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, body)
    |> Plug.Conn.halt()
  end
end
