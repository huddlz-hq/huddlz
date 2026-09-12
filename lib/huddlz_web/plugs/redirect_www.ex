defmodule HuddlzWeb.Plugs.RedirectWww do
  @moduledoc """
  Sends www visitors to the primary host before rendering a LiveView page.
  """

  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{host: "www.huddlz.com"} = conn, _opts) do
    location = "https://huddlz.com" <> conn.request_path <> query_suffix(conn.query_string)

    conn
    |> put_resp_header("location", location)
    |> send_resp(301, "")
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp query_suffix(""), do: ""
  defp query_suffix(query), do: "?" <> query
end
