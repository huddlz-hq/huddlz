defmodule HuddlzWeb.Api.EndToEndTest do
  @moduledoc """
  End-to-end happy path covering register → sign_in → create_group →
  create_huddl → RSVP → list my RSVPs → sign_out.

  This catches integration problems even when each unit test passes
  (e.g. schema not registered, route not forwarded, plug ordering wrong).
  """

  use HuddlzWeb.ApiCase, async: true

  test "API happy path", %{conn: conn} do
    # 1. Register
    register_resp =
      conn
      |> post("/api/auth/register", %{
        "email" => "happy-path@example.com",
        "display_name" => "Happy Path",
        "password" => "correct horse battery staple",
        "password_confirmation" => "correct horse battery staple"
      })
      |> json_response(201)

    assert %{"token" => token, "user" => %{"id" => user_id}} = register_resp
    assert is_binary(token)

    # 2. Sign in (independent — tokens are equivalent)
    sign_in_resp =
      conn
      |> post("/api/auth/sign_in", %{
        "email" => "happy-path@example.com",
        "password" => "correct horse battery staple"
      })
      |> json_response(200)

    assert %{"token" => signed_in_token} = sign_in_resp

    # 3. Create a group via JSON:API
    group_resp =
      conn
      |> put_req_header("authorization", "Bearer " <> signed_in_token)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/json/groups", %{
        "data" => %{
          "type" => "group",
          "attributes" => %{
            "name" => "Happy Path Group",
            "description" => "End-to-end test",
            "location" => "Tucson",
            "is_public" => true,
            "slug" => "happy-path-group"
          }
        }
      })
      |> json_response(201)

    assert %{"data" => %{"id" => group_id}} = group_resp

    # 4. Create a huddl via the resource action (the JSON:API create takes
    # virtual `date`/`start_time` args that are awkward over JSON:API today
    # but fully supported via the action)
    {:ok, huddl} =
      Huddlz.Communities.Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Happy Path Huddl",
          description: "tests",
          date: Date.add(Date.utc_today(), 7),
          start_time: ~T[14:00:00],
          duration_minutes: 60,
          creator_id: user_id,
          group_id: group_id,
          event_type: :in_person,
          physical_location: "123 Test St",
          is_private: false
        },
        actor: %Huddlz.Accounts.User{id: user_id, role: :user}
      )
      |> Ash.create()

    # 5. RSVP via PATCH
    rsvp_resp =
      conn
      |> put_req_header("authorization", "Bearer " <> signed_in_token)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/json/huddlz/#{huddl.id}/rsvp", %{
        "data" => %{"type" => "huddl", "attributes" => %{}}
      })

    assert %{"data" => %{"id" => returned_id}} = json_response(rsvp_resp, 200)
    assert returned_id == huddl.id

    # 6. List my RSVPs
    my_rsvps_resp =
      conn
      |> put_req_header("authorization", "Bearer " <> signed_in_token)
      |> get("/api/json/huddl_attendees/mine")
      |> json_response(200)

    assert %{"data" => attendees} = my_rsvps_resp
    assert length(attendees) == 1

    # 7. me query via GraphQL with the same token
    me_resp =
      conn
      |> put_req_header("authorization", "Bearer " <> signed_in_token)
      |> gql_post("{ me { id displayName } }")
      |> json_response(200)

    assert %{"data" => %{"me" => %{"id" => ^user_id, "displayName" => "Happy Path"}}} = me_resp

    # 8. Sign out — token now revoked
    delete_resp =
      conn
      |> put_req_header("authorization", "Bearer " <> signed_in_token)
      |> delete("/api/auth/sign_out")

    assert delete_resp.status == 204

    revoked_attempt =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> signed_in_token)
      |> get("/api/auth/me")

    assert json_response(revoked_attempt, 401) == %{"error" => "Authentication required"}
  end
end
