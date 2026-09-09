defmodule HuddlzWeb.Api.Json.GroupTest do
  use HuddlzWeb.ApiCase, async: true
  require Ash.Query

  test "group search accepts location and distance arguments", %{conn: conn} do
    owner = generate(user())
    nearby = generate(group(latitude: 30.2672, longitude: -97.7431, actor: owner))
    generate(group(latitude: 29.7604, longitude: -95.3698, actor: owner))

    conn =
      get(conn, "/api/json/groups/search", %{
        search_latitude: 30.2672,
        search_longitude: -97.7431,
        distance_miles: 25
      })

    assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
    assert id == nearby.id
  end

  describe "GET /api/json/groups" do
    test "lists public groups with their attributes", %{conn: conn} do
      owner = generate(user())

      g =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            actor: owner,
            name: "Surfaces Attributes",
            description: "must round-trip",
            location: "Tucson"
          )
        )

      conn = get(conn, "/api/json/groups")

      assert %{"data" => data} = json_response(conn, 200)
      record = Enum.find(data, &(&1["id"] == g.id))
      assert record, "expected the just-created group in the list"

      attrs = record["attributes"] || %{}
      assert attrs["name"] == "Surfaces Attributes"
      assert attrs["description"] == "must round-trip"
      assert attrs["location"] == "Tucson"
      assert attrs["is_public"] == true
    end
  end

  describe "DELETE /api/json/groups/:id" do
    test "owner can destroy a non-empty group; dependents cascade", %{conn: conn} do
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
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/groups/#{g.id}")

      assert conn.status in [200, 204], "got #{conn.status}: #{conn.resp_body}"

      # Group itself is gone
      assert {:error, _} = Ash.get(Huddlz.Communities.Group, g.id, authorize?: false)

      # The huddl that lived in the group is gone
      assert {:error, _} = Ash.get(Huddlz.Communities.Huddl, h.id, authorize?: false)

      # And so are the attendees of that huddl
      attendees =
        Huddlz.Communities.HuddlAttendee
        |> Ash.Query.filter(huddl_id: h.id)
        |> Ash.read!(authorize?: false)

      assert attendees == []
    end

    test "non-owner cannot delete the group", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      stranger = generate(user())

      conn =
        conn
        |> authenticated_conn(stranger)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/groups/#{g.id}")

      assert conn.status in [403, 404]
    end
  end

  describe "PATCH /api/json/groups/:id" do
    test "rejects blank descriptions and preserves the existing description", %{conn: conn} do
      owner = generate(user())
      group = generate(group(description: "A community for readers", actor: owner))

      for description <- [nil, "", " \t\n\u00A0 "] do
        response =
          conn
          |> authenticated_conn(owner)
          |> put_req_header("content-type", "application/vnd.api+json")
          |> patch("/api/json/groups/#{group.id}", %{
            "data" => %{"type" => "group", "attributes" => %{"description" => description}}
          })

        assert %{"errors" => [error]} = json_response(response, 400)
        assert error["source"]["pointer"] == "/data/attributes/description"
        assert error["detail"] =~ "is required"
      end

      response = get(conn, "/api/json/groups/#{group.id}")
      assert %{"data" => %{"attributes" => attributes}} = json_response(response, 200)
      assert attributes["description"] == "A community for readers"
    end

    test "legacy groups allow unrelated edits but reject resubmitting a missing description", %{
      conn: conn
    } do
      owner = generate(user())
      group = generate(group(actor: owner)) |> Ash.Seed.update!(%{description: nil})
      conn = authenticated_conn(conn, owner)

      response =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/groups/#{group.id}", %{
          "data" => %{"type" => "group", "attributes" => %{"name" => "Renamed Reading Club"}}
        })

      assert %{"data" => %{"attributes" => attributes}} = json_response(response, 200)
      assert attributes["name"] == "Renamed Reading Club"
      assert attributes["description"] == nil

      response =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/groups/#{group.id}", %{
          "data" => %{"type" => "group", "attributes" => %{"description" => nil}}
        })

      assert %{"errors" => [error]} = json_response(response, 400)
      assert error["source"]["pointer"] == "/data/attributes/description"
    end

    test "owner can update group details", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/groups/#{g.id}", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{"description" => "Updated description"}
          }
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == g.id

      reloaded = Ash.get!(Huddlz.Communities.Group, g.id, authorize?: false)
      assert reloaded.description |> to_string() == "Updated description"
    end

    test "non-owner cannot update group details", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      stranger = generate(user())

      conn =
        conn
        |> authenticated_conn(stranger)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/groups/#{g.id}", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{"description" => "I shouldn't be able to do this"}
          }
        })

      assert conn.status in [403, 404]
    end
  end

  describe "POST /api/json/groups" do
    test "requires a nonblank description", %{conn: conn} do
      owner = generate(user())

      for description <- [
            %{},
            %{"description" => nil},
            %{"description" => ""},
            %{"description" => " \t\n\u00A0 "}
          ] do
        attributes =
          Map.merge(
            %{
              "name" => "Reading Club",
              "location" => "Tucson",
              "latitude" => 32.2226,
              "longitude" => -110.9747,
              "time_zone" => "America/Phoenix"
            },
            description
          )

        response =
          conn
          |> authenticated_conn(owner)
          |> put_req_header("content-type", "application/vnd.api+json")
          |> post("/api/json/groups", %{
            "data" => %{"type" => "group", "attributes" => attributes}
          })

        assert %{"errors" => [error]} = json_response(response, 400)
        assert error["source"]["pointer"] == "/data/attributes/description"
        assert error["detail"] =~ "is required"
      end
    end

    test "creates a group and auto-generates slug from name when omitted", %{conn: conn} do
      me = generate(user())

      conn =
        conn
        |> authenticated_conn(me)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/groups", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{
              "name" => "API Created Group",
              "description" => "Created via JSON:API",
              "location" => "Tucson",
              "latitude" => 32.2226,
              "longitude" => -110.9747,
              "time_zone" => "America/Phoenix",
              "is_public" => true
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["id"])
      assert data["attributes"]["slug"] == Slug.slugify("API Created Group")
    end

    test "honors a caller-supplied slug", %{conn: conn} do
      me = generate(user())

      conn =
        conn
        |> authenticated_conn(me)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/groups", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{
              "name" => "Slug Customizer",
              "description" => "uses a custom slug",
              "location" => "Tucson",
              "latitude" => 32.2226,
              "longitude" => -110.9747,
              "time_zone" => "America/Phoenix",
              "is_public" => true,
              "slug" => "my-custom-slug"
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["attributes"]["slug"] == "my-custom-slug"
    end
  end

  describe "GET /api/json/groups/mine" do
    test "returns groups the actor owns or has joined", %{conn: conn} do
      me = generate(user())
      mine = generate(group(owner_id: me.id, is_public: true, actor: me))

      other_owner = generate(user())
      joined = generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))
      generate(group_member(group_id: joined.id, user_id: me.id, actor: other_owner))

      _stranger_group =
        generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))

      conn =
        conn
        |> authenticated_conn(me)
        |> get("/api/json/groups/mine")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert mine.id in ids
      assert joined.id in ids
      assert length(ids) == 2
    end
  end

  describe "GET /api/json/groups/search" do
    test "matches groups by name via trigram search", %{conn: conn} do
      owner = generate(user())

      target =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            actor: owner,
            name: "Phoenix Engineers"
          )
        )

      conn = get(conn, "/api/json/groups/search?query=Phoenix")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert target.id in ids
    end
  end

  describe "GET /api/json/groups/by_slug/:slug" do
    test "returns the group by slug", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = get(conn, "/api/json/groups/by_slug/#{g.slug}")

      assert %{"data" => %{"id" => id}} = json_response(conn, 200)
      assert id == g.id
    end
  end
end
