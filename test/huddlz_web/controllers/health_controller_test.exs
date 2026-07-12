defmodule HuddlzWeb.HealthControllerTest do
  use HuddlzWeb.ConnCase, async: true

  test "GET /healthz reports that Phoenix, Postgres, and Oban are ready", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert response(conn, 200) == "ok"
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
