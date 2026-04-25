defmodule HuddlzWeb.ApiCaseTest do
  use HuddlzWeb.ApiCase, async: true

  describe "authenticated_conn/2" do
    test "adds a bearer JWT to the authorization header", %{conn: conn} do
      user = generate(user())
      conn = authenticated_conn(conn, user)

      assert ["Bearer " <> token] = get_req_header(conn, "authorization")
      assert {:ok, _claims, _resource} = AshAuthentication.Jwt.verify(token, :huddlz)
    end
  end

  describe "gql_post/3" do
    test "POSTs a GraphQL introspection query and returns a JSON response", %{conn: conn} do
      conn = gql_post(conn, "{ __schema { queryType { name } } }")

      assert conn.status == 200

      assert %{"data" => %{"__schema" => %{"queryType" => %{"name" => _}}}} =
               json_response(conn, 200)
    end
  end
end
