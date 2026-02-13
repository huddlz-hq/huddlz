defmodule HuddlzWeb.JsonApiTest do
  use HuddlzWeb.ConnCase, async: true

  import Mox

  setup :verify_on_exit!

  describe "JSON:API authentication" do
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

    test "unauthenticated POST returns error", %{conn: conn, group: group, owner: owner} do
      starts_at =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.to_iso8601()

      ends_at =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.add(1, :hour)
        |> DateTime.to_iso8601()

      payload = %{
        data: %{
          type: "huddl",
          attributes: %{
            title: "Unauthorized Huddl",
            event_type: "in_person",
            physical_location: "123 Main St",
            starts_at: starts_at,
            ends_at: ends_at,
            creator_id: owner.id,
            group_id: group.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/huddlz", Jason.encode!(payload))

      assert conn.status in [403]
    end

    test "authenticated POST succeeds", %{conn: conn, owner: owner, group: group} do
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

      payload = %{
        data: %{
          type: "huddl",
          attributes: %{
            title: "Authorized Huddl",
            event_type: "in_person",
            physical_location: "456 Oak Ave",
            starts_at: starts_at,
            ends_at: ends_at,
            creator_id: owner.id,
            group_id: group.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/json/huddlz", Jason.encode!(payload))

      assert conn.status == 201
    end

    test "unauthenticated GET succeeds", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/huddlz?date_filter=upcoming")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert is_list(body["data"])
    end
  end
end
