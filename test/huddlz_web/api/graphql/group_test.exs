defmodule HuddlzWeb.Api.Graphql.GroupTest do
  use HuddlzWeb.ApiCase, async: true

  describe "listGroups query" do
    test "lists public groups", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = gql_post(conn, "{ listGroups { results { id } } }")

      assert %{"data" => %{"listGroups" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert g.id in ids
    end
  end

  describe "searchGroups query" do
    test "accepts location and distance arguments", %{conn: conn} do
      owner = generate(user())
      nearby = generate(group(latitude: 30.2672, longitude: -97.7431, actor: owner))
      generate(group(latitude: 29.7604, longitude: -95.3698, actor: owner))

      conn =
        gql_post(conn, """
        { searchGroups(searchLatitude: 30.2672, searchLongitude: -97.7431, distanceMiles: 25) {
          results { id }
        } }
        """)

      assert %{"data" => %{"searchGroups" => %{"results" => [%{"id" => id}]}}} =
               json_response(conn, 200)

      assert id == nearby.id
    end

    test "matches groups by name via trigram search", %{conn: conn} do
      owner = generate(user())

      target =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            actor: owner,
            name: "Elixir Developers"
          )
        )

      conn = gql_post(conn, ~s|{ searchGroups(search: "Elixir") { results { id } } }|)

      assert %{"data" => %{"searchGroups" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert target.id in ids
    end
  end

  describe "getGroup query" do
    test "returns the group by slug", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = gql_post(conn, ~s|{ getGroup(slug: "#{g.slug}") { id slug } }|)

      assert %{"data" => %{"getGroup" => %{"id" => id}}} = json_response(conn, 200)
      assert id == g.id
    end
  end

  describe "viewerGroups query" do
    test "returns groups the actor owns or has joined (default :all)", %{conn: conn} do
      member = generate(user())
      stranger = generate(user())

      owned = generate(group(name: "Owned by member", actor: member, is_public: true))

      joined =
        generate(group(name: "Joined by member", actor: stranger, is_public: true))

      generate(group_member(group_id: joined.id, user_id: member.id, actor: stranger))

      conn =
        conn
        |> authenticated_conn(member)
        |> gql_post("{ viewerGroups { results { id name } } }")

      assert %{"data" => %{"viewerGroups" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert owned.id in ids
      assert joined.id in ids
    end

    test "relationship: \"hosting\" returns only owned groups", %{conn: conn} do
      member = generate(user())
      stranger = generate(user())

      owned = generate(group(name: "Owned", actor: member, is_public: true))
      joined = generate(group(name: "Joined", actor: stranger, is_public: true))
      generate(group_member(group_id: joined.id, user_id: member.id, actor: stranger))

      conn =
        conn
        |> authenticated_conn(member)
        |> gql_post(~s|{ viewerGroups(relationship: "hosting") { results { id } } }|)

      assert %{"data" => %{"viewerGroups" => %{"results" => results}}} = json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert owned.id in ids
      refute joined.id in ids
    end

    test "relationship: \"joined\" returns only joined-but-not-owned groups", %{conn: conn} do
      member = generate(user())
      stranger = generate(user())

      owned = generate(group(name: "Owned", actor: member, is_public: true))
      joined = generate(group(name: "Joined", actor: stranger, is_public: true))
      generate(group_member(group_id: joined.id, user_id: member.id, actor: stranger))

      conn =
        conn
        |> authenticated_conn(member)
        |> gql_post(~s|{ viewerGroups(relationship: "joined") { results { id } } }|)

      assert %{"data" => %{"viewerGroups" => %{"results" => results}}} = json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert joined.id in ids
      refute owned.id in ids
    end

    test "returns empty list for an unrelated user", %{conn: conn} do
      lonely = generate(user())

      conn =
        conn
        |> authenticated_conn(lonely)
        |> gql_post("{ viewerGroups { results { id } } }")

      assert %{"data" => %{"viewerGroups" => %{"results" => []}}} = json_response(conn, 200)
    end
  end
end
