defmodule CucumberDatabaseHelper do
  @moduledoc """
  Helper module to ensure database sandbox is properly set up for Cucumber tests.
  """

  alias Ecto.Adapters.SQL.Sandbox

  @doc """
  Ensures the database sandbox is checked out and in shared mode for the current process.
  """
  def ensure_sandbox do
    case Sandbox.checkout(Huddlz.Repo) do
      :ok ->
        Sandbox.mode(Huddlz.Repo, {:shared, self()})
        :ok

      {:already, :owner} ->
        # Already checked out, just ensure shared mode
        Sandbox.mode(Huddlz.Repo, {:shared, self()})
        :ok
    end
  end
end
