defmodule HuddlzWeb.Api.Graphql.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

  describe "upcomingHuddlz query" do
    test "returns future huddlz", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn = gql_post(conn, "{ upcomingHuddlz { id } }")

      assert %{"data" => %{"upcomingHuddlz" => results}} = json_response(conn, 200)
      ids = Enum.map(results, & &1["id"])
      assert h.id in ids
    end
  end

  describe "huddlzInGroup query" do
    test "returns future huddlz in the given group", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn =
        gql_post(conn, ~s|{ huddlzInGroup(groupId: "#{group.id}") { results { id } } }|)

      assert %{"data" => %{"huddlzInGroup" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert h.id in ids
    end
  end

  describe "pastHuddlz query" do
    test "returns past huddlz", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      h =
        generate(
          past_huddl(
            group_id: group.id,
            creator_id: owner.id,
            starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
            ends_at: DateTime.add(DateTime.utc_now(), -2, :day) |> DateTime.add(1, :hour),
            is_private: false,
            event_type: :in_person,
            physical_location: "456 Past St"
          )
        )

      conn = gql_post(conn, "{ pastHuddlz { id } }")

      assert %{"data" => %{"pastHuddlz" => results}} = json_response(conn, 200)
      ids = Enum.map(results, & &1["id"])
      assert h.id in ids
    end
  end
end
