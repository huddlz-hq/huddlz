defmodule Huddlz.Test.BrowserHelpers do
  @moduledoc false

  import ExUnit.Assertions
  import PhoenixTest.Playwright, only: [add_session_cookie: 3]

  def sign_in(conn, member) do
    {:ok, token, _claims} =
      AshAuthentication.Jwt.token_for_user(member, %{}, domain: Huddlz.Accounts)

    add_session_cookie(
      conn,
      [value: %{user_token: token, live_socket_id: "users_sessions:#{Base.url_encode64(token)}"}],
      HuddlzWeb.Endpoint.session_options()
    )
  end

  # PhoenixTest's visit returns on the load event, before LiveView joins. A key
  # or click in that gap lands on markup the join render then replaces.
  def visit(conn, path) do
    conn
    |> PhoenixTest.visit(path)
    |> await_live_view()
  end

  # Waits until the page's LiveView, if it has one, is connected. Use after any
  # full page load that visit/2 did not make, such as a plain form submission.
  def await_live_view(conn) do
    assert_browser(conn, ~s|!document.querySelector("[data-phx-main]:not(.phx-connected)")|)
  end

  # Observe actual browser state with a bounded wait; never simulate app behavior.
  def assert_browser(conn, expression) do
    assert {:ok, _} =
             PlaywrightEx.Frame.wait_for_function(conn.frame_id,
               expression: expression,
               timeout: 5_000
             )

    conn
  end
end
