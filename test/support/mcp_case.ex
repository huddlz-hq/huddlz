defmodule HuddlzWeb.McpCase do
  @moduledoc "HTTP client helpers exercising OAuth consent, PKCE, and MCP."
  import ExUnit.Assertions
  import Phoenix.ConnTest

  @endpoint HuddlzWeb.Endpoint
  @redirect_uri "http://127.0.0.1:54321/callback"

  def connect(conn, member) do
    metadata = conn |> get("/.well-known/oauth-authorization-server") |> json_response(200)
    assert metadata["code_challenge_methods_supported"] == ["S256"]

    client =
      conn
      |> json_post("/oauth/register", %{
        client_name: "huddlz acceptance client",
        redirect_uris: [@redirect_uri],
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        token_endpoint_auth_method: "none"
      })
      |> json_response(201)

    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    params = %{
      client_id: client["client_id"],
      redirect_uri: @redirect_uri,
      response_type: "code",
      code_challenge: challenge,
      code_challenge_method: "S256",
      scope: "mcp",
      resource: Huddlz.Oauth2Server.resource_url(),
      state: "acceptance-state"
    }

    authorization = get(conn, "/oauth/authorize?" <> URI.encode_query(params))
    sign_in = authorization |> recycle() |> get(redirected_to(authorization))
    form = sign_in |> html_response(200) |> Floki.parse_document!()
    action = form |> Floki.find("#password-sign-in-form") |> Floki.attribute("action") |> hd()
    csrf = form |> Floki.find("input[name=_csrf_token]") |> Floki.attribute("value") |> hd()

    signed_in =
      sign_in
      |> recycle()
      |> post(action, %{
        "_csrf_token" => csrf,
        "user" => %{"email" => to_string(member.email), "password" => "McpTestPassword321!"}
      })

    return_to = redirected_to(signed_in)
    assert String.starts_with?(return_to, "/oauth/authorize?")
    consent = signed_in |> recycle() |> get(return_to)

    html = html_response(consent, 200) |> Floki.parse_document!()
    sealed = html |> Floki.find("input[name=consent_request]") |> Floki.attribute("value") |> hd()
    csrf = html |> Floki.find("input[name=_csrf_token]") |> Floki.attribute("value") |> hd()

    approved =
      consent
      |> recycle()
      |> post("/oauth/authorize", %{
        "action" => "approve",
        "consent_request" => sealed,
        "_csrf_token" => csrf
      })

    callback =
      approved |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert callback["state"] == "acceptance-state"

    token_params = %{
      grant_type: "authorization_code",
      client_id: client["client_id"],
      code: callback["code"],
      redirect_uri: @redirect_uri,
      code_verifier: verifier,
      resource: Huddlz.Oauth2Server.resource_url()
    }

    tokens = conn |> json_post("/oauth/token", token_params) |> json_response(200)
    %{tokens: tokens, client_id: client["client_id"], token_params: token_params}
  end

  def rpc(oauth, method, params \\ %{}) do
    build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> oauth.tokens["access_token"])
    |> Plug.Conn.put_req_header("accept", "application/json, text/event-stream")
    |> json_post("/mcp", %{jsonrpc: "2.0", id: 1, method: method, params: params})
    |> json_response(200)
  end

  def call(oauth, name, arguments) do
    response = rpc(oauth, "tools/call", %{name: name, arguments: %{input: arguments}})
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
