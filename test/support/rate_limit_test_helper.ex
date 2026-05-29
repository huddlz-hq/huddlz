defmodule Huddlz.RateLimitTestHelper do
  @moduledoc """
  Enables the auth rate limiter for a single test. Limiting is off by default in
  the test env (see `config/test.exs`); call this from a `setup` block in the
  rate-limit tests, which must be `async: false` so the global flag can't leak into
  concurrently-running tests.
  """
  import ExUnit.Callbacks

  def enable_rate_limiting do
    Application.put_env(:huddlz, :rate_limit_enabled, true)
    on_exit(fn -> Application.put_env(:huddlz, :rate_limit_enabled, false) end)
    :ok
  end
end
