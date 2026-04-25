defmodule HuddlzWeb.Api.Json.HuddlAttendeeTest do
  use HuddlzWeb.ApiCase, async: true

  describe "GET /api/json/huddl_attendees/by_huddl" do
    test "organizer can see attendees of a huddl in their group", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: g.id, creator_id: owner.id, actor: owner))

      member = generate(user())

      h
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      conn =
        conn
        |> authenticated_conn(owner)
        |> get("/api/json/huddl_attendees/by_huddl?huddl_id=#{h.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert data != []
    end
  end

  describe "GET /api/json/huddl_attendees/mine" do
    test "returns only the actor's RSVPs", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: g.id, creator_id: owner.id, actor: owner))
      member = generate(user())

      h
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: member)
      |> Ash.update!()

      conn =
        conn
        |> authenticated_conn(member)
        |> get("/api/json/huddl_attendees/mine")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert data != []
    end
  end
end
