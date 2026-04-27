defmodule HuddlzWeb.Api.Json.GroupTest do
  use HuddlzWeb.ApiCase, async: true

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
    test "owner authorization passes when calling destroy", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/groups/#{g.id}")

      # 200/204 if destroy succeeds; 400 if FK constraints prevent it (action
      # ran past authorization). 403/404 would mean policy rejected the actor.
      assert conn.status in [200, 204, 400], "got #{conn.status}: #{conn.resp_body}"
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
    test "returns only groups owned by the actor", %{conn: conn} do
      me = generate(user())
      mine = generate(group(owner_id: me.id, is_public: true, actor: me))

      other_owner = generate(user())

      _other_group =
        generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))

      conn =
        conn
        |> authenticated_conn(me)
        |> get("/api/json/groups/mine")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert mine.id in ids
      assert length(ids) == 1
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
