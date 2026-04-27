defmodule HuddlzWeb.ApiAuth do
  @moduledoc """
  Plug wrapper around `AshAuthentication.Strategy.ApiKey.Plug`.

  `:load_from_bearer` and the API key plug both inspect
  `Authorization: Bearer <token>`. When a JWT has already authenticated
  the request, re-running the API key plug would attempt to validate the
  JWT as an API key and 401 a perfectly good request. This wrapper
  short-circuits when an actor is already loaded so the JWT path is
  preserved.

  When no actor is loaded yet, the wrapped plug runs normally — including
  its 401 `on_error` handler — so an invalid Bearer token is rejected
  rather than silently treated as anonymous.
  """

  @behaviour Plug

  alias AshAuthentication.Strategy.ApiKey.Plug, as: ApiKeyPlug

  @impl true
  def init(opts) do
    opts
    |> Keyword.put_new(:on_error, &__MODULE__.on_error/2)
    |> ApiKeyPlug.init()
  end

  @impl true
  def call(conn, config) do
    if Ash.PlugHelpers.get_actor(conn) do
      conn
    else
      ApiKeyPlug.call(conn, config)
    end
  end

  @doc """
  Default `on_error` handler. Returns the same JSON 401 body as
  `HuddlzWeb.Api.AuthController.auth_required/1` so all 401s from the
  API surface use a consistent shape.
  """
  def on_error(conn, _error) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(401, ~s({"error":"Authentication required"}))
    |> Plug.Conn.halt()
  end
end
