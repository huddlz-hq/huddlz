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
    test "returns future huddlz with their attributes", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn = gql_post(conn, "{ upcomingHuddlz { id title eventType startsAt } }")

      assert %{"data" => %{"upcomingHuddlz" => results}} = json_response(conn, 200)
      record = Enum.find(results, &(&1["id"] == h.id))
      assert record, "expected the new huddl in the upcoming list"
      assert is_binary(record["title"])
      assert record["eventType"] in ["in_person", "virtual", "hybrid"]
      assert is_binary(record["startsAt"])
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

  describe "searchHuddlz query — relationship arg" do
    setup do
      host = generate(user())
      attendee = generate(user())
      stranger = generate(user())

      host_group = generate(group(owner_id: host.id, is_public: true, actor: host))
      stranger_group = generate(group(owner_id: stranger.id, is_public: true, actor: stranger))

      hosted =
        generate(huddl(group_id: host_group.id, creator_id: host.id, actor: host))

      foreign =
        generate(huddl(group_id: stranger_group.id, creator_id: stranger.id, actor: stranger))

      foreign
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      %{host: host, attendee: attendee, hosted: hosted, foreign: foreign}
    end

    test "relationship hosting returns only huddlz the actor created", %{
      conn: conn,
      host: host,
      hosted: hosted,
      foreign: foreign
    } do
      conn =
        conn
        |> authenticated_conn(host)
        |> gql_post(~s|{ searchHuddlz(query: null, relationship: "hosting") { results { id } } }|)

      assert %{"data" => %{"searchHuddlz" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])

      assert hosted.id in ids
      refute foreign.id in ids
    end

    test "relationship attending returns RSVPed huddlz the actor did not create", %{
      conn: conn,
      attendee: attendee,
      foreign: foreign,
      hosted: hosted
    } do
      conn =
        conn
        |> authenticated_conn(attendee)
        |> gql_post(
          ~s|{ searchHuddlz(query: null, relationship: "attending") { results { id } } }|
        )

      assert %{"data" => %{"searchHuddlz" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])

      assert foreign.id in ids
      refute hosted.id in ids
    end

    test "anonymous actor with relationship filter returns []", %{conn: conn} do
      conn =
        gql_post(
          conn,
          ~s|{ searchHuddlz(query: null, relationship: "hosting") { results { id } } }|
        )

      assert %{"data" => %{"searchHuddlz" => %{"results" => []}}} = json_response(conn, 200)
    end
  end
end
