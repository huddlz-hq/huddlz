defmodule HuddlzWeb.HelpLiveTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Test.Helpers.Authentication

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
    |> assert_has("#help-developers a[href='/help/agents']", text: "Connect an agent")
    |> refute_has("#help-developers a[href='/profile/api-keys']")
    |> refute_has("#help-directory", text: "Coming soon")
  end

  test "people with a confirmed address also get a link to their API keys", %{conn: conn} do
    conn
    |> Authentication.login(generate(user()))
    |> visit("/help")
    |> assert_has("#help-developers a[href='/profile/api-keys']", text: "API keys")
  end
end
