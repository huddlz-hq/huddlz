defmodule ApiWaitlistSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest

  step "a full public huddl and an authenticated API caller", context do
    owner = generate(user())
    group = generate(group(actor: owner, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: owner, max_attendees: 1))
    Huddlz.Communities.rsvp_huddl!(huddl, actor: owner)
    caller = generate(user())

    Map.merge(context, %{
      waitlist_huddl: huddl,
      waitlist_owner: owner,
      waitlist_caller: caller,
      conn: authenticated_conn(context.conn, caller)
    })
  end

  step "I join the huddl waitlist through {string}", %{args: [api]} = context do
    request_attendance(context, api, "join_waitlist")
  end

  step "I RSVP to the huddl through {string}", %{args: [api]} = context do
    request_attendance(context, api, "rsvp")
  end

  step "I authenticate the waitlist caller with an API key", context do
    Map.put(context, :conn, api_key_conn(build_conn(), context.waitlist_caller))
  end

  step "the last confirmed attendee cancels", context do
    Huddlz.Communities.cancel_rsvp_huddl!(context.waitlist_huddl, actor: context.waitlist_owner)
    context
  end

  step "I cancel my attendance through {string}", %{args: [api]} = context do
    request_attendance(context, api, "cancel_rsvp")
  end

  step "the waitlist request is unavailable because {string}", %{args: [reason]} = context do
    unavailable_request(context, reason)
  end

  step "the API rejects the waitlist request", context do
    assert_rejected(context.waitlist_response, context.waitlist_api)
    context
  end

  step "my API attendance history is empty", context do
    response =
      build_conn()
      |> authenticated_conn(context.waitlist_caller)
      |> Phoenix.ConnTest.dispatch(
        HuddlzWeb.Endpoint,
        :get,
        "/api/json/huddl_attendees/mine",
        %{}
      )
      |> json_response(200)

    assert response["data"] == []
    context
  end

  step "I read the huddl attendance through {string} as {string}",
       %{args: [api, viewer]} = context do
    conn =
      case viewer do
        "myself" -> context.conn
        "another caller" -> authenticated_conn(build_conn(), generate(user()))
        "anonymous" -> build_conn()
      end

    response = read_attendance(conn, context.waitlist_huddl.id, api)

    Map.merge(context, %{
      waitlist_response: response,
      waitlist_api: api,
      attendance_action: "read"
    })
  end

  step "I am the confirmed attendee", context do
    Map.put(context, :conn, authenticated_conn(build_conn(), context.waitlist_owner))
  end

  step "the API reports my attendance as {string}", %{args: [state]} = context do
    response = json_response(context.waitlist_response, 200)
    assert attendance_state(response, context.waitlist_api, context.attendance_action) == state
    context
  end

  step "my API attendance history contains one waitlist entry", context do
    response =
      context.conn
      |> Phoenix.ConnTest.dispatch(
        HuddlzWeb.Endpoint,
        :get,
        "/api/json/huddl_attendees/mine",
        %{}
      )
      |> json_response(200)

    assert [entry] = response["data"]
    assert entry["attributes"]["waitlisted_at"] != nil
    context
  end

  step "the API does not list me as a confirmed attendee", context do
    response =
      context.conn
      |> gql_post("{ searchHuddlz(query: null, relationship: \"attending\") { results { id } } }")
      |> json_response(200)

    assert response["data"]["searchHuddlz"]["results"] == []
    context
  end

  defp request_attendance(context, api, action) do
    response = attendance_request(context.conn, context.waitlist_huddl.id, api, action)

    Map.merge(context, %{
      waitlist_response: response,
      waitlist_api: api,
      attendance_action: action
    })
  end

  defp attendance_request(conn, id, "JSON:API", action) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
    |> Phoenix.ConnTest.dispatch(
      HuddlzWeb.Endpoint,
      :patch,
      "/api/json/huddlz/#{id}/#{action}",
      %{
        "data" => %{"type" => "huddl", "id" => id, "attributes" => %{}}
      }
    )
  end

  defp attendance_request(conn, id, "GraphQL", action) do
    gql_post(conn, """
    mutation {
      #{mutation_name(action)}(id: "#{id}") {
        result { id attendanceState }
        errors { message }
      }
    }
    """)
  end

  defp attendance_state(response, "JSON:API", _action),
    do: response["data"]["attributes"]["attendance_state"]

  defp attendance_state(response, "GraphQL", "read") do
    refute Map.has_key?(response, "errors")
    response["data"]["getHuddl"]["attendanceState"]
  end

  defp attendance_state(response, "GraphQL", action) do
    assert response["data"][mutation_name(action)]["errors"] == []
    response["data"][mutation_name(action)]["result"]["attendanceState"]
  end

  defp read_attendance(conn, id, "JSON:API") do
    Phoenix.ConnTest.dispatch(conn, HuddlzWeb.Endpoint, :get, "/api/json/huddlz/#{id}", %{})
  end

  defp read_attendance(conn, id, "GraphQL") do
    gql_post(conn, ~s|{ getHuddl(id: "#{id}") { id attendanceState } }|)
  end

  defp unavailable_request(context, "anonymous"), do: Map.put(context, :conn, build_conn())

  defp unavailable_request(context, "missing huddl") do
    Map.put(context, :waitlist_huddl, %{id: Ash.UUID.generate()})
  end

  defp unavailable_request(context, "cancelled huddl") do
    Huddlz.Communities.cancel_huddl!(context.waitlist_huddl, nil, %{},
      actor: context.waitlist_owner
    )

    context
  end

  defp unavailable_request(context, "draft huddl") do
    huddl =
      generate(
        huddl(
          group_id: context.waitlist_huddl.group_id,
          actor: context.waitlist_owner,
          lifecycle_state: :draft,
          max_attendees: 1
        )
      )

    Map.put(context, :waitlist_huddl, huddl)
  end

  defp unavailable_request(context, "completed huddl") do
    ended =
      Ash.Seed.update!(context.waitlist_huddl, %{
        starts_at: DateTime.add(DateTime.utc_now(), -2, :hour),
        ends_at: DateTime.add(DateTime.utc_now(), -1, :hour)
      })

    completed = Huddlz.Communities.complete_huddl!(ended, authorize?: false)
    Map.put(context, :waitlist_huddl, completed)
  end

  defp unavailable_request(context, reason) do
    changes =
      case reason do
        "private huddl" -> %{is_private: true}
        "open seats" -> %{max_attendees: 2}
        "unlimited seats" -> %{max_attendees: nil}
      end

    Huddlz.Communities.update_huddl!(context.waitlist_huddl, changes,
      actor: context.waitlist_owner
    )

    context
  end

  defp assert_rejected(conn, "JSON:API") do
    assert conn.status in [400, 401, 403, 404, 422]
    assert [_ | _] = json_response(conn, conn.status)["errors"]
  end

  defp assert_rejected(conn, "GraphQL") do
    response = json_response(conn, 200)
    assert response["data"]["joinHuddlWaitlist"]["result"] == nil
    assert [_ | _] = response["data"]["joinHuddlWaitlist"]["errors"]
  end

  defp mutation_name("join_waitlist"), do: "joinHuddlWaitlist"
  defp mutation_name("cancel_rsvp"), do: "cancelRsvpToHuddl"
  defp mutation_name("rsvp"), do: "rsvpToHuddl"
end
