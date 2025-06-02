defmodule CucumberHooks do
  use Cucumber.Hooks

  # Hook that runs before every scenario to ensure database is set up
  before_scenario context do
    CucumberDatabaseHelper.ensure_sandbox()
    {:ok, context}
  end

  # Hook for @conn tag - creates a Phoenix connection
  before_scenario "@conn", context do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})

    {:ok, Map.put(context, :conn, conn)}
  end
end
