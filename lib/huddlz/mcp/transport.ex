defmodule Huddlz.MCP.Transport do
  @moduledoc false

  use GenServer

  alias MCP.Transport.StreamableHTTP.Plug, as: StreamableHTTPPlug

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def config, do: GenServer.call(__MODULE__, :config)

  @impl GenServer
  def init(_opts) do
    sessions = :ets.new(:huddlz_mcp_session_principals, [:set, :public])

    transport =
      StreamableHTTPPlug.init(
        server_mod: Huddlz.MCP.Handler,
        handler_opts: &handler_opts/1,
        server_opts: [
          server_info: %{name: "huddlz", version: "1.0.0"},
          instructions:
            "Use public discovery tools without authentication. Authenticated tools act only as the person represented by the bearer credential."
        ],
        enable_json_response: true
      )

    {:ok, %{sessions: sessions, transport: transport}}
  end

  @impl GenServer
  def handle_call(:config, _from, state), do: {:reply, state, state}

  defp handler_opts(conn), do: [actor: Ash.PlugHelpers.get_actor(conn)]
end
