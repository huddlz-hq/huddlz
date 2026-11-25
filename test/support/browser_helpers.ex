defmodule Huddlz.Test.BrowserHelpers do
  @moduledoc false

  def sign_in(session, member) do
    {:ok, token, _claims} =
      AshAuthentication.Jwt.token_for_user(member, %{}, domain: Huddlz.Accounts)

    Fluffy.add_session_cookie(session, %{
      "user_token" => token,
      "live_socket_id" => "users_sessions:#{Base.url_encode64(token)}"
    })
  end

  # Observe actual browser state with a bounded wait; never simulate app behavior.
  def assert_browser(session, expression),
    do: Fluffy.Playwright.wait_for_function(session, expression, timeout: 5_000)
end
