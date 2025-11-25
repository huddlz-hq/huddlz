ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

Cucumber.compile_features!()
