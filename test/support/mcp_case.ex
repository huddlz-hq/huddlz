defmodule HuddlzWeb.McpCase do
  @moduledoc "HTTP client helpers for an agent calling MCP with an API key."
  import ExUnit.Assertions
  import Phoenix.ConnTest

  @endpoint HuddlzWeb.Endpoint

  @doc "Give `member` an API key for their agent, as the API keys page would."
  def connect(member, opts \\ []) do
    expires_at = Keyword.get(opts, :expires_at, DateTime.add(DateTime.utc_now(), 30 * 86_400))

    record =
      Huddlz.Accounts.ApiKey
      |> Ash.Changeset.for_create(:create, %{name: "Test agent", expires_at: expires_at},
        actor: member
      )
      |> Ash.create!()

    %{key: record.__metadata__.plaintext_api_key, record: record}
  end

  @doc "A JSON-RPC request to /mcp with the agent's key, as its raw response."
  def post_rpc(agent, method, params \\ %{}) do
    build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> agent.key)
    |> Plug.Conn.put_req_header("accept", "application/json, text/event-stream")
    |> json_post("/mcp", %{jsonrpc: "2.0", id: 1, method: method, params: params})
  end

  def rpc(agent, method, params \\ %{}) do
    agent |> post_rpc(method, params) |> json_response(200)
  end

  def call(agent, name, arguments) do
    response = rpc(agent, "tools/call", %{name: name, arguments: %{input: arguments}})
    assert response["error"] == nil, inspect(response)
    result = response["result"]
    refute result["isError"], inspect(result)
    [%{"text" => text} | _] = result["content"]
    Jason.decode!(text)
  end

  def json_post(conn, path, params) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(params))
  end
end
