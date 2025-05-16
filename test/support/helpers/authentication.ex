defmodule Huddlz.Test.Helpers.Authentication do
  alias Huddlz.Accounts.User
  alias Huddlz.Accounts

  @spec login(Plug.Conn.t(), %User{}) :: Plug.Conn.t()
  def login(conn, user) do
    case AshAuthentication.Jwt.token_for_user(user, %{}, domain: Accounts) do
      {:ok, token, _claims} ->
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:error, reason} ->
        raise "Failed to generate token: #{inspect(reason)}"
    end
  end

  def create_user(opts \\ %{}) do
    User
    |> Ash.Seed.seed!(opts |> Enum.into(%{email: Faker.Internet.email()}))
  end
end
