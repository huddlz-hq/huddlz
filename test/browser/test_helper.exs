# Throwaway prototype: loaded only by mix test.browser.
ExUnit.start(capture_log: true, max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

System.put_env("PLAYWRIGHT_BROWSERS_PATH", Path.expand("_build/browser-prototype/browsers"))
Application.put_env(:phoenix_test, :otp_app, :huddlz)
Application.put_env(:phoenix_test, :base_url, HuddlzWeb.Endpoint.url())

Application.put_env(:phoenix_test, :playwright,
  browser_pools: [[id: :default_pool, size: 1]],
  screenshot: true,
  screenshot_dir: "_build/browser-prototype/screenshots",
  trace: true,
  trace_dir: "_build/browser-prototype/traces"
)

{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
