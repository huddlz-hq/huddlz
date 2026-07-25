defmodule HuddlzWeb.AuthLive.ReturnToTest do
  use HuddlzWeb.ConnCase, async: true

  import PhoenixTest

  describe "authentication return paths" do
    test "preserves a local huddl path between sign-in and registration", %{conn: conn} do
      return_to = "/groups/book-club/huddlz/123"

      conn
      |> visit("/sign-in?" <> URI.encode_query(return_to: return_to))
      |> assert_has(
        "form[action='/auth/user/password/sign_in?return_to=%2Fgroups%2Fbook-club%2Fhuddlz%2F123']"
      )
      |> assert_has(
        "a[href='/register?return_to=%2Fgroups%2Fbook-club%2Fhuddlz%2F123']",
        text: "Sign up"
      )
      |> click_link("Sign up")
      |> assert_path("/register", query_params: %{"return_to" => return_to})
      |> assert_has(
        "a[href='/sign-in?return_to=%2Fgroups%2Fbook-club%2Fhuddlz%2F123']",
        text: "Sign in"
      )
    end

    test "does not propagate external return paths", %{conn: conn} do
      conn
      |> visit("/sign-in?return_to=https%3A%2F%2Fevil.example")
      |> assert_has("form[action='/auth/user/password/sign_in']")
      |> assert_has("a[href='/register']", text: "Sign up")
    end
  end
end
