defmodule Huddlz.Accounts.Generators.UserGenerator do
  @moduledoc """
  Generators for creating User test data.
  """
  use Ash.Generator

  alias Huddlz.Accounts.User

  @doc """
  Create a user with the given email or a random one.
  """
  def user(opts \\ []) do
    email = Keyword.get(opts, :email, Faker.Internet.email())
    role = Keyword.get(opts, :role, :regular)

    seed_generator(
      %User{email: email, role: role},
      overrides: opts
    )
  end
end
