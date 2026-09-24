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

  A request signed in with an API key records the key's use, which the
  API keys page shows as "Used … ago". A failure to record it never fails
  the request.
  """

  @behaviour Plug

  require Logger

  alias AshAuthentication.Strategy.ApiKey.Plug, as: ApiKeyPlug
  alias Huddlz.Accounts.{ApiKey, User}

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
      conn |> ApiKeyPlug.call(config) |> mark_key_used()
    end
  end

  @doc """
  `on_error` handler for MCP, where every call needs a signed-in person.
  The body tells an agent what to send instead of a bare refusal.
  """
  def mcp_on_error(conn, _error) do
    body =
      Jason.encode!(%{
        error: "Authentication required: send an API key as Authorization: Bearer <key>.",
        help: HuddlzWeb.Endpoint.url() <> "/help/agents"
      })

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.put_resp_header("cache-control", "no-store")
    |> Plug.Conn.send_resp(401, body)
    |> Plug.Conn.halt()
  end

  defp mark_key_used(
         %{assigns: %{current_user: %User{__metadata__: %{api_key: %ApiKey{} = key}} = user}} =
           conn
       ) do
    case key |> Ash.Changeset.for_update(:mark_used, %{}, actor: user) |> Ash.update() do
      {:ok, _key} ->
        :ok

      {:error, error} ->
        Logger.warning("could not record an API key's use: #{Exception.message(error)}")
    end

    conn
  end

  defp mark_key_used(conn), do: conn

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
