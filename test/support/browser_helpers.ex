defmodule Huddlz.Test.BrowserHelpers do
  @moduledoc false

  import Fluffy.PhoenixTest, only: [unwrap: 2]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 4]

  def sign_in(conn, member) do
    {:ok, token, _claims} =
      AshAuthentication.Jwt.token_for_user(member, %{}, domain: Huddlz.Accounts)

    # One request through the endpoint signs the session cookie.
    signed =
      build_conn()
      |> Plug.Test.init_test_session(%{
        user_token: token,
        live_socket_id: "users_sessions:#{Base.url_encode64(token)}"
      })
      |> dispatch(HuddlzWeb.Endpoint, :get, "/")

    cookies =
      for {name, %{value: value}} <- signed.resp_cookies,
          do: %{name: name, value: value, url: Fluffy.base_url(conn.session)}

    %{conn | session: Fluffy.add_cookies(conn.session, cookies)}
  end

  # Observe actual browser state with a bounded wait; never simulate app behavior.
  def assert_browser(conn, expression) do
    unwrap(conn, &Playwright.Page.wait_for_function!(&1, expression, nil, timeout: 5_000))
  end
end
