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

  describe "DELETE /sign-out" do
    test "clears the session and protects authenticated pages from browser history", %{
      conn: conn
    } do
      user = create_test_user()
      conn = login(conn, user)

      assert is_binary(get_session(conn, :user_token))

      conn = get(conn, ~p"/profile")

      assert get_resp_header(conn, "cache-control") == ["no-store"]

      conn =
        conn
        |> recycle()
        |> delete(~p"/sign-out")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed out"
      refute get_session(conn, :user_token)

      signed_out_conn =
        conn
        |> recycle()
        |> get(~p"/profile")

      assert redirected_to(signed_out_conn) == ~p"/sign-in?#{[return_to: "/profile"]}"
    end

    test "disconnects LiveViews using the signed-in session", %{conn: conn} do
      user = create_test_user()
      conn = login(conn, user)
      live_socket_id = get_session(conn, :live_socket_id)

      Phoenix.PubSub.subscribe(Huddlz.PubSub, live_socket_id)

      delete(conn, ~p"/sign-out")

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^live_socket_id,
        event: "disconnect",
        payload: %{}
      }
    end
  end

  test "password reset starts a usable session while an earlier session remains revoked", %{
    conn: conn
  } do
    member =
      generate(user_with_password()) |> Ash.Seed.update!(%{confirmed_at: DateTime.utc_now()})

    earlier = login(build_conn(), member)

    {:ok, reset_token, _} =
      AshAuthentication.Jwt.token_for_user(
        member,
        %{"act" => "reset_password_with_token"},
        domain: Huddlz.Accounts
      )

    conn =
      post(conn, "/auth/user/password/reset", %{
        "user" => %{
          "reset_token" => reset_token,
          "password" => "ChangedPassword123!",
          "password_confirmation" => "ChangedPassword123!"
        }
      })

    assert redirected_to(conn) == "/"
    assert get_session(conn, :return_to) == nil
    assert conn |> recycle() |> get("/profile/api-keys") |> html_response(200) =~ "API keys"
    old = earlier |> recycle() |> get("/profile/api-keys")
    assert URI.parse(redirected_to(old)).path == "/sign-in"
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
