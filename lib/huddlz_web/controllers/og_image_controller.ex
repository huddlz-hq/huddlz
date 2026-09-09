defmodule HuddlzWeb.OgImageController do
  @moduledoc """
  Serves the generated link-preview card for a public huddl. Private or
  unpublished huddlz are as invisible here as they are on their page.
  """
  use HuddlzWeb, :controller

  alias Huddlz.Communities
  alias HuddlzWeb.OgImage

  require Logger

  def huddl(conn, %{"id" => id}) do
    with {:ok, huddl} <- Communities.get_huddl(id, load: [:status, :group], actor: nil),
         true <- shareable?(huddl) do
      send_card(conn, huddl)
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  defp send_card(conn, huddl) do
    etag = OgImage.etag(huddl)

    conn =
      conn
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> put_resp_header("etag", etag)
      |> put_resp_header("x-content-type-options", "nosniff")

    if etag in get_req_header(conn, "if-none-match") do
      send_resp(conn, 304, "")
    else
      draw(conn, huddl)
    end
  end

  defp draw(conn, huddl) do
    case OgImage.huddl_card(huddl) do
      {:ok, png} ->
        conn |> put_resp_content_type("image/png") |> send_resp(200, png)

      {:error, reason} ->
        Logger.error("Could not draw the preview card for huddl #{huddl.id}: #{inspect(reason)}")
        conn |> delete_resp_header("cache-control") |> send_resp(500, "Preview unavailable")
    end
  end

  defp shareable?(%{is_private: false, group: %{is_public: true}, lifecycle_state: state})
       when state in [:published, :completed, :cancelled],
       do: true

  defp shareable?(_huddl), do: false
end
