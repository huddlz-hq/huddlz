defmodule HuddlzWeb.Api.Graphql.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

  describe "me query" do
    test "returns the current actor when authenticated", %{conn: conn} do
      target = generate(user(display_name: "Me"))

      conn =
        conn
        |> authenticated_conn(target)
        |> gql_post("{ me { id displayName } }")

      assert %{"data" => %{"me" => %{"id" => id, "displayName" => "Me"}}} =
               json_response(conn, 200)

      assert id == target.id
    end
  end

  describe "updateDisplayName mutation" do
    test "actor updates their own display name", %{conn: conn} do
      target = generate(user(display_name: "Old"))

      query = """
      mutation {
        updateDisplayName(id: "#{target.id}", input: {displayName: "New"}) {
          result { displayName }
          errors { message }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(target)
        |> gql_post(query)

      assert %{"data" => %{"updateDisplayName" => %{"result" => result, "errors" => errors}}} =
               json_response(conn, 200)

      assert errors in [nil, []]
      assert result["displayName"] == "New"
    end
  end

  describe "cancelRsvpToHuddl mutation" do
    test "is idempotent when actor is not RSVPed", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
      member = generate(user())

      query = """
      mutation { cancelRsvpToHuddl(id: "#{h.id}") { result { id } errors { message } } }
      """

      conn =
        conn
        |> authenticated_conn(member)
        |> gql_post(query)

      assert %{
               "data" => %{
                 "cancelRsvpToHuddl" => %{"result" => %{"id" => id}, "errors" => errors}
               }
             } = json_response(conn, 200)

      assert id == h.id
      assert errors in [nil, []]
    end
  end

  describe "rsvpToHuddl mutation" do
    test "RSVPs the actor to the huddl", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
      member = generate(user())

      query = """
      mutation { rsvpToHuddl(id: "#{h.id}") { result { id } errors { message } } }
      """

      conn =
        conn
        |> authenticated_conn(member)
        |> gql_post(query)

      assert %{"data" => %{"rsvpToHuddl" => %{"result" => %{"id" => id}, "errors" => errors}}} =
               json_response(conn, 200)

      assert id == h.id
      assert errors in [nil, []]
    end
  end

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
