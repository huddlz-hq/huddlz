defmodule HuddlzWeb.ErrorHTMLTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  describe "404 recovery page" do
    test "renders a branded, private recovery page" do
      html =
        render_to_string(HuddlzWeb.ErrorHTML, "404", "html",
          reason: "secret exception detail",
          stack: ["private stack"],
          current_user: nil
        )

      assert html =~ "<title>404 · huddlz</title>"
      assert html =~ "This path doesn’t lead to a huddl."
      assert html =~ "Private and missing pages look the same here."
      assert html =~ ~s(aria-label="Recovery options")
      assert html =~ ~s(href="/">)
      assert html =~ "huddlz home"
      assert html =~ "Discover huddlz"
      assert html =~ ~s(id="error-home")
      assert html =~ ~s(id="error-discover")
      refute html =~ ~s(id="error-retry")
      assert html =~ ~s(name="robots" content="noindex, nofollow")
      refute html =~ "secret exception detail"
      refute html =~ "private stack"
    end

    test "uses the signed-in recovery destination" do
      html =
        render_to_string(HuddlzWeb.ErrorHTML, "404", "html", current_user: %{id: "person-id"})

      assert html =~ ~s(href="/calendar")
      assert html =~ "Back to Calendar"
      refute html =~ "huddlz home"
    end
  end

  describe "500 recovery page" do
    test "renders a safe retry path without query parameters" do
      html =
        render_to_string(HuddlzWeb.ErrorHTML, "500", "html",
          error_request_path: "/groups/example",
          current_user: nil,
          reason: "password=do-not-render",
          status: 500
        )

      assert html =~ "<title>500 · huddlz</title>"
      assert html =~ "We lost the thread."
      assert html =~ "Try this page again"
      assert html =~ ~s(id="error-retry")
      assert html =~ ~s(href="/groups/example")
      refute html =~ "password=do-not-render"
    end

    test "falls back to home for unsafe network-path retry URLs" do
      for unsafe_path <- ["//outside.example/path", "/\\outside.example/path"] do
        html =
          render_to_string(HuddlzWeb.ErrorHTML, "500", "html",
            error_request_path: unsafe_path,
            current_user: nil
          )

        refute html =~ ~s(href="#{unsafe_path}")
        assert html =~ ~r/<a id="error-retry"[^>]*href="\/">/
      end
    end
  end

  test "keeps Phoenix status messages for errors outside the requested scope" do
    assert render_to_string(HuddlzWeb.ErrorHTML, "422", "html", []) ==
             "Unprocessable Content"
  end

  describe "endpoint rendering" do
    test "returns the branded page and correct status for an unknown route", %{conn: conn} do
      conn = get(conn, "/a-route-that-does-not-exist?token=private")

      assert html_response(conn, 404) =~ "This path doesn’t lead to a huddl."
      refute response(conn, 404) =~ "token=private"
    end

    test "preserves a signed-in browser recovery destination", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> login(user)
        |> get("/another-route-that-does-not-exist")

      assert html_response(conn, 404) =~ "Back to Calendar"
      refute response(conn, 404) =~ "huddlz home"
    end

    test "returns the branded page and correct status for a missing group", %{conn: conn} do
      assert {404, _headers, body} =
               assert_error_sent(404, fn ->
                 get(conn, ~p"/groups/group-that-does-not-exist")
               end)

      assert body =~ "This path doesn’t lead to a huddl."
      refute body =~ "Group not found"
    end

    test "uses the signed-in shell for a missing huddl", %{conn: conn} do
      user = create_user()

      assert {404, _headers, body} =
               assert_error_sent(404, fn ->
                 conn
                 |> login(user)
                 |> get(~p"/groups/missing-group/huddlz/#{Ash.UUID.generate()}")
               end)

      assert body =~ "Back to Calendar"
      refute body =~ "huddlz home"
    end

    test "renders a safe 500 response through the endpoint", %{conn: conn} do
      assert {500, _headers, body} =
               assert_error_sent(500, fn ->
                 get(conn, "/__test__/errors/500?token=private")
               end)

      assert body =~ "We lost the thread."
      assert body =~ ~s(href="/__test__/errors/500")
      refute body =~ "token=private"
      refute body =~ "private runtime failure"
    end

    test "preserves the signed-in recovery destination after an unexpected failure", %{
      conn: conn
    } do
      user = create_user()

      assert {500, _headers, body} =
               assert_error_sent(500, fn ->
                 conn
                 |> login(user)
                 |> get("/__test__/errors/500")
               end)

      assert body =~ "Back to Calendar"
      refute body =~ "huddlz home"
    end
  end
end
