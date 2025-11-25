defmodule CucumberHooks do
  use Cucumber.Hooks

  alias Ecto.Adapters.SQL.Sandbox

  # Hook for @database tag - sets up database sandbox
  before_scenario "@database", context do
    case Sandbox.checkout(Huddlz.Repo) do
      :ok -> :ok
      {:already, :owner} -> :ok
    end

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
