defmodule Huddlz.SoireeFixture do
  @moduledoc """
  Test fixtures for soirées.

  Uses generators to create test data for feature tests.
  """

  alias Huddlz.Accounts.Generators.UserGenerator
  alias Huddlz.Soirees.Generators.SoireeGenerator
  alias Ash.Generator

  @doc """
  Create sample soirées for testing.
  Returns a list of created soirées.
  """
  def create_sample_soirees(count \\ 3) do
    # Create test host or get existing one
    host =
      case Ash.get(Huddlz.Accounts.User, email: "test.host@example.com") do
        {:ok, user} ->
          user

        _ ->
          UserGenerator.user(email: "test.host@example.com") |> Generator.generate()
      end

    # Get existing soirees
    {:ok, existing_soirees} = Ash.read(Huddlz.Soirees.Soiree)

    # If we already have at least the requested count, return them
    if length(existing_soirees) >= count do
      Enum.take(existing_soirees, count)
    else
      # Create unique soirees with different titles for each
      for i <- 1..count do
        SoireeGenerator.soiree(host: host, title: "Test Soirée #{i}")
        |> Generator.generate()
      end
    end
  end
end
