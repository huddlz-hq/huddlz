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
