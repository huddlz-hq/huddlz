defmodule HuddlzWeb.GraphqlTest do
  use HuddlzWeb.ConnCase, async: true

  import Mox

  setup :verify_on_exit!

  describe "GraphQL HTTP authentication" do
    setup do
      stub(Huddlz.MockGeocoding, :geocode, fn _address ->
        {:ok, %{latitude: 30.27, longitude: -97.74}}
      end)

      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            title: "Test Huddl"
          )
        )

      %{owner: owner, group: group, huddl: huddl}
    end

    test "unauthenticated create mutation returns error", %{
      conn: conn,
      group: group,
      owner: owner
    } do
      starts_at =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.to_iso8601()

      ends_at =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.add(1, :hour)
        |> DateTime.to_iso8601()

      query = """
      mutation CreateHuddl($input: CreateHuddlInput!) {
        createHuddl(input: $input) {
          result {
            id
          }
          errors {
            message
          }
        }
      }
      """

      variables = %{
        input: %{
          title: "Unauthorized Huddl",
          eventType: "in_person",
          physicalLocation: "123 Main St",
          groupId: group.id,
          creatorId: owner.id,
          startsAt: starts_at,
          endsAt: ends_at
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/gql", Jason.encode!(%{query: query, variables: variables}))

      body = json_response(conn, 200)

      # Without a token, the mutation should fail with errors
      has_mutation_errors = body["data"]["createHuddl"]["errors"] != []
      has_top_level_errors = body["errors"] != nil

      assert has_mutation_errors || has_top_level_errors
    end

    test "authenticated create mutation succeeds", %{conn: conn, owner: owner, group: group} do
      {:ok, token, _claims} =
        AshAuthentication.Jwt.token_for_user(owner, %{}, domain: Huddlz.Accounts)

      starts_at =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.to_iso8601()

      ends_at =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.add(1, :hour)
        |> DateTime.to_iso8601()

      query = """
      mutation CreateHuddl($input: CreateHuddlInput!) {
        createHuddl(input: $input) {
          result {
            id
          }
          errors {
            message
          }
        }
      }
      """

      variables = %{
        input: %{
          title: "Authorized Huddl",
          eventType: "in_person",
          physicalLocation: "456 Oak Ave",
          groupId: group.id,
          creatorId: owner.id,
          startsAt: starts_at,
          endsAt: ends_at
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/gql", Jason.encode!(%{query: query, variables: variables}))

      body = json_response(conn, 200)

      assert body["data"]["createHuddl"]["result"]["id"] != nil
      assert body["data"]["createHuddl"]["errors"] == []
    end

    test "unauthenticated read query succeeds", %{conn: conn, huddl: huddl} do
      query = """
      {
        searchHuddlz {
          count
          results {
            id
          }
        }
      }
      """

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/gql", Jason.encode!(%{query: query}))

      body = json_response(conn, 200)
      results = body["data"]["searchHuddlz"]["results"]
      assert is_list(results)
      assert Enum.any?(results, fn r -> r["id"] == huddl.id end)
    end
  end
end
