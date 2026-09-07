defmodule HuddlzWeb.SitemapController do
  use HuddlzWeb, :controller
  alias Huddlz.Sitemaps

  def robots(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> send_resp(200, "User-agent: *\nAllow: /\nSitemap: #{url(~p"/sitemap.xml")}\n")
  end

  def index(conn, _params), do: serve(conn, "sitemap.xml")
  def child(conn, %{"file" => file}), do: serve(conn, "sitemap-#{file}")

  defp serve(conn, name) do
    case Sitemaps.fetch(name) do
      nil when name == "sitemap.xml" ->
        conn
        |> put_resp_header("retry-after", "900")
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(503, "Sitemap is being prepared")

      nil ->
        conn |> put_resp_header("cache-control", "no-store") |> send_resp(404, "Not found")

      "" ->
        conn |> put_resp_header("cache-control", "public, max-age=300") |> send_resp(204, "")

      body ->
        etag = "\"#{Sitemaps.digest(body)}\""

        conn =
          conn
          |> put_resp_content_type("application/xml")
          |> put_resp_header("cache-control", "public, max-age=300")
          |> put_resp_header("etag", etag)
          |> put_resp_header("x-content-type-options", "nosniff")

        if etag in get_req_header(conn, "if-none-match"),
          do: send_resp(conn, 304, ""),
          else: send_resp(conn, 200, body)
    end
  end
end
