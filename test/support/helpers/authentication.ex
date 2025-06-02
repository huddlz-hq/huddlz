defmodule Huddlz.Test.Helpers.Authentication do
  @moduledoc """
  Test helper functions for user authentication in tests.
  """

  alias AshAuthentication.Plug.Helpers
  alias Huddlz.Accounts
  alias Huddlz.Accounts.User

  @spec login(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
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

  # Alternative login method using AshAuthentication's store_in_session
  # This method stores the user directly in the session instead of using JWT tokens
  def login_with_session(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Helpers.store_in_session(user)
  end

  def create_user(opts \\ []) do
    opts = Enum.into(opts, [])
    Huddlz.Generator.generate(Huddlz.Generator.user(opts))
  end
end
