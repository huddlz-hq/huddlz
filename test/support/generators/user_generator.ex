defmodule Huddlz.Generators.UserGenerator do
  @moduledoc """
  Generators for creating User test data.
  """
  use Ash.Generator

  alias Huddlz.Accounts.User

  @doc """
  Create a user with the given email or a random one.
  """
  def user(opts \\ []) do
    email = Keyword.get(opts, :email, "user-#{Enum.random(1..10000)}@example.com")

    seed_generator(
      %User{email: email},
      overrides: opts
    )
  end
end
