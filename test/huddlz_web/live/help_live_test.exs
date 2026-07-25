defmodule HuddlzWeb.HelpLiveTest do
  use HuddlzWeb.ConnCase, async: true

  test "shows only working support, developer, legal, and source destinations", %{conn: conn} do
    conn
    |> visit("/help")
    |> assert_has("#help-support a[href='mailto:support@huddlz.com']")
    |> assert_has("#help-support a[href='https://github.com/huddlz-hq/huddlz/issues']")
    |> assert_has("#help-developers a[href='/api/json/swaggerui']")
    |> assert_has("#help-developers a[href='/gql/playground']")
    |> assert_has("#help-developers a[href='https://github.com/huddlz-hq/huddlz']")
    |> assert_has("#help-legal a[href='/terms']")
    |> assert_has("#help-legal a[href='/code-of-conduct']")
    |> assert_has("#help-legal a[href='/privacy']")
    |> refute_has("#help-directory", text: "Coming soon")
    |> refute_has("#help-directory", text: "MCP")
  end
end
