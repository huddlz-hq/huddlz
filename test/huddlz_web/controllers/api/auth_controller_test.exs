defmodule HuddlzWeb.Api.AuthControllerTest do
  use HuddlzWeb.ApiCase, async: true
  import Swoosh.TestAssertions

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

  describe "DELETE /api/auth/sign_out" do
    test "revokes the bearer JWT and returns 204", %{conn: conn} do
      user = generate(user())
      authed_conn = authenticated_conn(conn, user)
      bearer = authed_conn |> get_req_header("authorization") |> List.first()

      response = delete(authed_conn, "/api/auth/sign_out")
      assert response.status == 204
      assert response.resp_body == ""

      follow_up =
        build_conn()
        |> put_req_header("authorization", bearer)
        |> get("/api/auth/me")

      assert json_response(follow_up, 401) == %{"error" => "Authentication required"}
    end

    test "returns 401 when no bearer is provided", %{conn: conn} do
      conn = delete(conn, "/api/auth/sign_out")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end

  describe "POST /api/auth/password_reset" do
    test "returns 204 and emails a reset link for a known email", %{conn: conn} do
      generate(user_with_password(email: "reset-known@example.com"))
      # Clear the registration confirmation email
      assert_email_sent()

      conn = post(conn, "/api/auth/password_reset", %{"email" => "reset-known@example.com"})

      assert conn.status == 204

      assert_email_sent(fn email ->
        email.to == [{"", "reset-known@example.com"}] and
          email.subject == "Reset your password"
      end)
    end

    test "returns 204 and sends no email for an unknown email", %{conn: conn} do
      conn = post(conn, "/api/auth/password_reset", %{"email" => "nobody-reset@example.com"})

      assert conn.status == 204
      refute_email_sent()
    end

    test "returns 204 when email param is missing", %{conn: conn} do
      conn = post(conn, "/api/auth/password_reset", %{})

      assert conn.status == 204
      refute_email_sent()
    end
  end
end
