defmodule HuddlzWeb.ErrorContext do
  @moduledoc """
  Captures the small amount of safe browser context needed by static error pages.

  This plug runs before the router so an unknown route can still distinguish an
  authenticated browser session from a signed-out request. API and GraphQL
  requests keep their existing bearer-token authentication paths.
  """

  import Plug.Conn

  alias AshAuthentication.Phoenix.Plug, as: AuthenticationPlug

  @non_browser_prefixes ~w(/api /gql /ws)

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn = assign(conn, :error_request_path, conn.request_path)

    if browser_request?(conn) do
      conn
      |> fetch_session()
      |> AuthenticationPlug.load_from_session([])
    else
      conn
    end
  end

  defp browser_request?(conn) do
    browser_path?(conn.request_path) and accepts_html?(get_req_header(conn, "accept"))
  end

  defp browser_path?("/healthz"), do: false

  defp browser_path?(path) do
    Enum.all?(@non_browser_prefixes, fn prefix ->
      path != prefix and not String.starts_with?(path, prefix <> "/")
    end)
  end

  defp accepts_html?([]), do: true

  defp accepts_html?(headers) do
    Enum.any?(headers, fn header ->
      String.contains?(header, "text/html") or String.contains?(header, "*/*")
    end)
  end
end
