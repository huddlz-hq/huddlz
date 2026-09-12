defmodule HuddlzWeb.WwwRedirectTest do
  use HuddlzWeb.ConnCase, async: true

  test "redirects the home page without adding a query delimiter" do
    conn = get(build_conn(), "https://www.huddlz.com/")

    assert redirected_to(conn, 301) == "https://huddlz.com/"
    assert conn.halted
  end

  test "preserves encoded paths and repeated query parameters for HEAD requests" do
    path = "/groups/board%20games?tag=a&tag=b&return=%2Fdiscover"
    conn = head(build_conn(), "https://www.huddlz.com" <> path)

    assert redirected_to(conn, 301) == "https://huddlz.com" <> path
  end

  test "keeps the primary host, local hosts, and Fly health checks reachable" do
    for host <- ["huddlz.com", "localhost", "huddlz.fly.dev", "www.huddlz.com.example"] do
      conn = get(build_conn(), "https://#{host}/healthz")

      assert conn.status == 200
      assert get_resp_header(conn, "location") == []
    end
  end
end
