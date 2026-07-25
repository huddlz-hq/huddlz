defmodule HuddlzWeb.AuthControllerTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Accounts.User
  alias HuddlzWeb.AuthController

  test "redirects after authentication only to a validated local path", %{conn: conn} do
    user = create_test_user()

    safe_conn = %{
      (init_test_session(conn, %{})
       |> Phoenix.Controller.fetch_flash([]))
      | params: %{"return_to" => "/groups/book-club/huddlz/123"}
    }

    assert redirected_to(AuthController.success(safe_conn, {:password, :sign_in}, user, nil)) ==
             "/groups/book-club/huddlz/123"

    unsafe_conn = %{
      (init_test_session(conn, %{})
       |> Phoenix.Controller.fetch_flash([]))
      | params: %{"return_to" => "https://evil.example"}
    }

    assert redirected_to(AuthController.success(unsafe_conn, {:password, :sign_in}, user, nil)) ==
             "/"
  end

  defp create_test_user do
    user =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: "user#{System.unique_integer([:positive])}@example.com",
        display_name: "Test User",
        role: :user
      })
      |> Ash.create!(authorize?: false)

    {:ok, token, _claims} =
      AshAuthentication.Jwt.token_for_user(user, %{}, domain: Huddlz.Accounts)

    %{user | __metadata__: Map.put(user.__metadata__, :token, token)}
  end
end
