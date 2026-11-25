# Loaded only by mix test.browser.
ExUnit.start(capture_log: true, max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)
# Set here, not in config: the fast Cucumber suite's steps are no Playwright tests.
Application.put_env(:cucumber, :step_wrapper, {HuddlzWeb.BrowserCase, :wrap})

System.put_env("PLAYWRIGHT_BROWSERS_PATH", Path.expand("_build/browser/browsers"))
