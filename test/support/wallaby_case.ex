defmodule HuddlzWeb.WallabyCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require Wallaby for browser automation.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query
      import Huddlz.Generator

      alias HuddlzWeb.Router.Helpers, as: Routes

      @endpoint HuddlzWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Huddlz.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Huddlz.Repo, {:shared, self()})
    end

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Huddlz.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    {:ok, session: session}
  end
end
