defmodule HuddlzWeb.OgImageController do
  @moduledoc """
  Serves the generated link-preview card for a public huddl or group, and the
  site card every other page shares. Private or unpublished huddlz and groups
  are as invisible here as they are on their page.
  """
  use HuddlzWeb, :controller

  alias Huddlz.Communities
  alias HuddlzWeb.OgImage

  require Logger

  def site(conn, _params) do
    send_card(conn, OgImage.site_etag(), &OgImage.site_card/0, "the site")
  end

  def huddl(conn, %{"id" => id}) do
    with {:ok, huddl} <- Communities.get_huddl(id, load: [:status, :group], actor: nil),
         true <- shareable?(huddl) do
      send_card(conn, OgImage.etag(huddl), fn -> OgImage.huddl_card(huddl) end, "huddl #{id}")
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  def group(conn, %{"slug" => slug}) do
    case Communities.get_by_slug(slug, load: [:member_count], actor: nil) do
      {:ok, %{is_public: true} = group} ->
        send_card(
          conn,
          OgImage.group_etag(group),
          fn -> OgImage.group_card(group) end,
          "group #{slug}"
        )

      _ ->
        send_resp(conn, 404, "Not found")
    end
  end

  defp send_card(conn, etag, draw, subject) do
    conn =
      conn
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> put_resp_header("etag", etag)
      |> put_resp_header("x-content-type-options", "nosniff")

    if etag in get_req_header(conn, "if-none-match") do
      send_resp(conn, 304, "")
    else
      respond(conn, draw.(), subject)
    end
  end

  defp respond(conn, {:ok, png}, _subject) do
    conn |> put_resp_content_type("image/png") |> send_resp(200, png)
  end

  defp respond(conn, {:error, reason}, subject) do
    Logger.error("Could not draw the preview card for #{subject}: #{inspect(reason)}")
    conn |> delete_resp_header("cache-control") |> send_resp(500, "Preview unavailable")
  end

  defp shareable?(%{is_private: false, group: %{is_public: true}, lifecycle_state: state})
       when state in [:published, :completed, :cancelled],
       do: true

  defp shareable?(_huddl), do: false
end
