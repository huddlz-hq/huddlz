defmodule HuddlzWeb.Api.AuthControllerTest do
  use HuddlzWeb.ApiCase, async: true

  describe "POST /api/auth/register" do
    test "creates a user and returns a JWT that authenticates the user", %{conn: conn} do
      params = %{
        "email" => "alice@example.com",
        "display_name" => "Alice",
        "password" => "correct horse battery staple",
        "password_confirmation" => "correct horse battery staple"
      }

      conn = post(conn, "/api/auth/register", params)

      assert %{"token" => token, "user" => user} = json_response(conn, 201)
      assert user["email"] == "alice@example.com"
      assert user["display_name"] == "Alice"
      assert is_binary(user["id"])
      assert is_binary(token)

      assert {:ok, _claims, _user_resource} = AshAuthentication.Jwt.verify(token, :huddlz)
    end

    test "rejects duplicate email with 422", %{conn: conn} do
      _existing = generate(user(email: "taken@example.com"))

      params = %{
        "email" => "taken@example.com",
        "display_name" => "New",
        "password" => "correct horse battery staple",
        "password_confirmation" => "correct horse battery staple"
      }

      conn = post(conn, "/api/auth/register", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_list(errors) and errors != []
    end

    test "rejects password shorter than 8 chars with 422", %{conn: conn} do
      params = %{
        "email" => "weak@example.com",
        "display_name" => "Weak",
        "password" => "short",
        "password_confirmation" => "short"
      }

      conn = post(conn, "/api/auth/register", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_list(errors) and errors != []
    end

    test "rejects mismatched password confirmation with 422", %{conn: conn} do
      params = %{
        "email" => "mismatch@example.com",
        "display_name" => "Mismatch",
        "password" => "correct horse battery staple",
        "password_confirmation" => "different password"
      }

      conn = post(conn, "/api/auth/register", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_list(errors) and errors != []
    end
  end

  describe "POST /api/auth/sign_in" do
    test "returns a JWT on correct credentials", %{conn: conn} do
      generate(
        user_with_password(
          email: "signin@example.com",
          password: "correct horse battery staple"
        )
      )

      conn =
        post(conn, "/api/auth/sign_in", %{
          "email" => "signin@example.com",
          "password" => "correct horse battery staple"
        })

      assert %{"token" => token, "user" => %{"email" => "signin@example.com"}} =
               json_response(conn, 200)

      assert is_binary(token)
      assert {:ok, _claims, _user_resource} = AshAuthentication.Jwt.verify(token, :huddlz)
    end

    test "returns 401 on wrong password", %{conn: conn} do
      generate(user_with_password(email: "wrong-pass@example.com", password: "Password123!"))

      conn =
        post(conn, "/api/auth/sign_in", %{
          "email" => "wrong-pass@example.com",
          "password" => "totally wrong"
        })

      assert json_response(conn, 401) == %{"error" => "Invalid email or password"}
    end

    test "returns the same 401 shape on unknown email", %{conn: conn} do
      conn =
        post(conn, "/api/auth/sign_in", %{
          "email" => "nobody@example.com",
          "password" => "anything goes here"
        })

      assert json_response(conn, 401) == %{"error" => "Invalid email or password"}
    end
  end

  describe "GET /api/auth/me" do
    test "returns the current user with a valid bearer", %{conn: conn} do
      target = generate(user(email: "me@example.com", display_name: "Me"))

      conn =
        conn
        |> authenticated_conn(target)
        |> get("/api/auth/me")

      assert %{"user" => user} = json_response(conn, 200)
      assert user["id"] == target.id
      assert user["email"] == "me@example.com"
      assert user["display_name"] == "Me"
    end

    test "returns 401 when no bearer is provided", %{conn: conn} do
      conn = get(conn, "/api/auth/me")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end

    test "returns 401 when the bearer is malformed", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not.a.real.jwt")
        |> get("/api/auth/me")

      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end
end
