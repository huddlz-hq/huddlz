ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, :manual)

# Load Cucumber support files before compiling features
Code.require_file("features/support/database_helper.exs", __DIR__)

Cucumber.compile_features!()
