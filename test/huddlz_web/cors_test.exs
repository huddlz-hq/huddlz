defmodule HuddlzWeb.CorsTest do
  use HuddlzWeb.ConnCase, async: true

  describe "CORS preflight" do
    test "OPTIONS request from an origin echoes the origin and returns CORS headers" do
      conn =
        build_conn()
        |> put_req_header("origin", "http://localhost:5173")
        |> put_req_header("access-control-request-method", "POST")
        |> put_req_header("access-control-request-headers", "content-type,authorization")
        |> dispatch(@endpoint, :options, "/api/json/huddlz")

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5173"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
      assert [methods] = get_resp_header(conn, "access-control-allow-methods")
      assert String.contains?(methods, "POST")
    end
  end

  describe "CORS actual request" do
    test "request with origin header receives access-control-allow-origin in response" do
      conn =
        build_conn()
        |> put_req_header("origin", "http://localhost:5173")
        |> get("/api/json/huddlz")

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5173"]
    end

    test "request without origin header receives no CORS headers" do
      conn = get(build_conn(), "/api/json/huddlz")
      assert get_resp_header(conn, "access-control-allow-origin") == []
    end
  end

  describe "HuddlzWeb.Cors.matches?/2" do
    test "returns true when configured for :all" do
      assert HuddlzWeb.Cors.matches?("http://anything.example", :all)
    end

    test "returns true only for listed origins" do
      origins = ["https://app.huddlz.com"]

      assert HuddlzWeb.Cors.matches?("https://app.huddlz.com", origins)
      refute HuddlzWeb.Cors.matches?("https://evil.example", origins)
    end

    test "returns false when no origins are configured" do
      refute HuddlzWeb.Cors.matches?("https://app.huddlz.com", [])
    end
  end
end
