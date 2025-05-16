defmodule Huddlz.HuddlFixture do
  @moduledoc """
  Test fixtures for huddls.

  Uses generators to create test data for feature tests.
  """

  alias Huddlz.Accounts.Generators.UserGenerator
  alias Huddlz.Communities.Generators.HuddlGenerator
  alias Ash.Generator

  @doc """
  Create sample huddls for testing.
  Returns a list of created huddls.
  """
  def create_sample_huddls(count \\ 3) do
    # Create test host or get existing one
    host =
      case Ash.get(Huddlz.Accounts.User, email: "test.host@example.com") do
        {:ok, user} ->
          user

        _ ->
          UserGenerator.user(email: "test.host@example.com") |> Generator.generate()
      end

    # Get existing huddls
    {:ok, existing_huddls} = Ash.read(Huddlz.Communities.Huddl)

    # If we already have at least the requested count, return them
    if length(existing_huddls) >= count do
      Enum.take(existing_huddls, count)
    else
      # Create unique huddls with different titles for each
      for i <- 1..count do
        HuddlGenerator.huddl(host: host, title: "Test Huddl #{i}")
        |> Generator.generate()
      end
    end
  end
end
