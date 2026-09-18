defmodule HuddlzWeb.AuthLive.TokenExchangeTest do
  use HuddlzWeb.ConnCase, async: true

  alias Phoenix.LiveViewTest, as: LiveViewTest
  require LiveViewTest

  test "sign-in exchanges credentials in a POST body and preserves the destination", %{conn: conn} do
    user = generate(user_with_password(password: "Password123!"))
    {:ok, view, _html} = LiveViewTest.live(conn, "/sign-in?return_to=%2Fprofile")

    view
    |> LiveViewTest.form("#password-sign-in-form", %{
      user: %{email: to_string(user.email), password: "Password123!"}
    })
    |> LiveViewTest.render_submit()

    conn = exchange_token(view, conn)

    assert redirected_to(conn) == "/profile"
    assert conn.assigns.current_user.id == user.id
  end

  test "registration exchanges credentials in a POST body and preserves the destination", %{
    conn: conn
  } do
    {:ok, view, _html} = LiveViewTest.live(conn, "/register?return_to=%2Fprofile")

    view
    |> LiveViewTest.form("#registration-form", %{
      user: %{
        email: "post-register@example.com",
        display_name: "New Member",
        password: "Password123!",
        password_confirmation: "Password123!",
        legal_acceptance: true
      }
    })
    |> LiveViewTest.render_submit()

    conn = exchange_token(view, conn)

    assert redirected_to(conn) == "/profile"
    assert to_string(conn.assigns.current_user.email) == "post-register@example.com"
  end

  test "the token exchange route does not accept GET requests", %{conn: conn} do
    conn = get(conn, "/auth/user/password/sign_in_with_token?token=invalid")

    assert conn.status == 404
    refute get_session(conn, :user_token)
  end

  defp exchange_token(view, conn) do
    conn =
      view
      |> LiveViewTest.form("#sign-in-token-form")
      |> LiveViewTest.follow_trigger_action(conn)

    assert conn.method == "POST"
    assert conn.query_string == ""
    assert is_binary(conn.body_params["token"])
    assert is_binary(get_session(conn, :user_token))
    conn
  end
end
