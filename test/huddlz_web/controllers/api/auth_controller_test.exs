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
end
