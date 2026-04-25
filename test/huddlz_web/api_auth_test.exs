defmodule HuddlzWeb.ApiAuthTest do
  @moduledoc """
  Cross-cutting tests for the API authentication pipelines.

  Verifies that the JWT plug (`:load_from_bearer`) and the API-key plug
  (`AshAuthentication.Strategy.ApiKey.Plug`) co-exist on both the `:api`
  and `:graphql` pipelines.
  """

  use HuddlzWeb.ApiCase, async: true

  describe "Authorization: Bearer <jwt> on the :api pipeline" do
    test "authenticates the actor", %{conn: conn} do
      target = generate(user())

      conn =
        conn
        |> authenticated_conn(target)
        |> get("/api/auth/me")

      assert %{"user" => %{"id" => id}} = json_response(conn, 200)
      assert id == target.id
    end
  end

  describe "Authorization: Bearer <api_key> on the :api pipeline" do
    test "authenticates the actor", %{conn: conn} do
      target = generate(user())

      conn =
        conn
        |> api_key_conn(target)
        |> get("/api/auth/me")

      assert %{"user" => %{"id" => id}} = json_response(conn, 200)
      assert id == target.id
    end

    test "expired API key results in unauthenticated access", %{conn: conn} do
      target = generate(user())

      conn =
        conn
        |> api_key_conn(target, expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second))
        |> get("/api/auth/me")

      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end

  describe ":graphql pipeline" do
    test "JWT bearer does not break introspection", %{conn: conn} do
      target = generate(user())

      conn =
        conn
        |> authenticated_conn(target)
        |> gql_post("{ __schema { queryType { name } } }")

      assert %{"data" => %{"__schema" => _}} = json_response(conn, 200)
    end

    test "API key bearer does not break introspection", %{conn: conn} do
      target = generate(user())

      conn =
        conn
        |> api_key_conn(target)
        |> gql_post("{ __schema { queryType { name } } }")

      assert %{"data" => %{"__schema" => _}} = json_response(conn, 200)
    end

    test "no bearer does not break introspection", %{conn: conn} do
      conn = gql_post(conn, "{ __schema { queryType { name } } }")
      assert %{"data" => %{"__schema" => _}} = json_response(conn, 200)
    end
  end
end
