# Loaded only by mix test.browser.
ExUnit.start(capture_log: true, max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

System.put_env("PLAYWRIGHT_BROWSERS_PATH", Path.expand("_build/browser/browsers"))
Application.put_env(:phoenix_test, :otp_app, :huddlz)
Application.put_env(:phoenix_test, :base_url, HuddlzWeb.Endpoint.url())

Application.put_env(:phoenix_test, :playwright,
  browser_context_opts: [timezone_id: "America/New_York"],
  browser_pools: [[id: :default_pool, size: 1]],
  screenshot: true,
  screenshot_dir: "_build/browser/screenshots",
  trace: true,
  trace_dir: "_build/browser/traces"
)

{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
