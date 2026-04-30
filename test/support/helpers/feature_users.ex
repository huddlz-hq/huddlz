defmodule Huddlz.Test.Helpers.FeatureUsers do
  @moduledoc """
  Step-definition helpers for finding users seeded by the
  "the following users exist" Cucumber step.
  """

  import ExUnit.Assertions

  @doc """
  Find a user in the scenario context by email, or fail the test.
  """
  def find_user!(users, email) do
    case Enum.find(users, fn u -> to_string(u.email) == email end) do
      nil -> flunk("No user with email #{email} in scenario context")
      user -> user
    end
  end
end
