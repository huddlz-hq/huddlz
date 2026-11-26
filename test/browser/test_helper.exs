# Loaded only by mix test.browser.
ExUnit.start(capture_log: true, max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

System.put_env("PLAYWRIGHT_BROWSERS_PATH", Path.expand("_build/browser/browsers"))
