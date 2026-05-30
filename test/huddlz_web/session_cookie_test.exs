defmodule HuddlzWeb.SessionCookieTest do
  # Guards the session cookie's `secure` flag wiring. `secure: true` is set
  # only in production (config/prod.exs); if it ever leaked into the base or
  # test config the cookie would stop being sent over http and local dev /
  # the test suite's session-based auth would silently break.
  use ExUnit.Case, async: true

  test "the session cookie is not forced secure outside production" do
    refute get_in(Application.get_env(:huddlz, :session) || [], [:secure])
  end
end
