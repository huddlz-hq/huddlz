defmodule TurnoutSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}

  step "the {word} huddl {string} in {string} ended yesterday with {int} RSVPs",
       %{args: [kind, title, group_name, rsvps]} = context do
    starts_at = DateTime.add(DateTime.utc_now(), -1, :day)
    huddl = seed_huddl(kind, title, group_name, starts_at)
    add_rsvps(huddl, rsvps)
    remember(context, huddl)
  end

  step "the {word} huddl {string} in {string} is upcoming with {int} RSVPs",
       %{args: [kind, title, group_name, rsvps]} = context do
    starts_at = DateTime.add(DateTime.utc_now(), 3, :day)
    huddl = seed_huddl(kind, title, group_name, starts_at)
    add_rsvps(huddl, rsvps)
    remember(context, huddl)
  end

  step "the turnout for {string} was recorded as {int} in the room",
       %{args: [title, in_room]} = context do
    huddl = find_huddl(title)
    owner = Ash.get!(User, huddl.group.owner_id, authorize?: false)
    Communities.record_turnout!(huddl, %{in_room: in_room}, actor: owner)
    context
  end

  step "I visit the huddl {string}", %{args: [title]} = context do
    huddl = find_huddl(title)
    session = visit(context.conn, "/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "the API hides the turnout of {string} from {string}",
       %{args: [title, email]} = context do
    huddl = find_huddl(title)
    viewer = find_user(email)

    json =
      build_conn()
      |> authenticated_conn(viewer)
      |> Phoenix.ConnTest.dispatch(HuddlzWeb.Endpoint, :get, "/api/json/huddlz/#{huddl.id}", %{})
      |> json_response(200)

    attributes = json["data"]["attributes"]
    assert is_nil(attributes["turnout_in_room"])
    assert is_nil(attributes["turnout_on_call"])
    assert is_nil(attributes["show_rate"])

    gql =
      build_conn()
      |> authenticated_conn(viewer)
      |> gql_post(~s|{ getHuddl(id: "#{huddl.id}") { id turnoutInRoom turnoutOnCall showRate } }|)
      |> json_response(200)

    assert is_nil(gql["data"]["getHuddl"]["turnoutInRoom"])
    assert is_nil(gql["data"]["getHuddl"]["showRate"])
    context
  end

  step "{string} records {int} in the room and {int} on the call for {string} through {string}",
       %{args: [email, in_room, on_call, title, api]} = context do
    huddl = find_huddl(title)
    conn = authenticated_conn(build_conn(), find_user(email))
    response = record_request(conn, huddl.id, api, in_room, on_call)
    Map.merge(context, %{turnout_response: response, turnout_api: api})
  end

  step "the API shows {string} with {int} in the room, {int} on the call and a {int}% show rate",
       %{args: [_title, in_room, on_call, rate]} = context do
    json = json_response(context.turnout_response, 200)
    {got_room, got_call, got_rate} = recorded_values(json, context.turnout_api)
    assert {got_room, got_call, got_rate} == {in_room, on_call, rate}
    context
  end

  step "the API refuses the turnout", context do
    case context.turnout_api do
      "JSON:API" ->
        assert context.turnout_response.status in [403, 404]

      "GraphQL" ->
        json = json_response(context.turnout_response, 200)
        mutation = json["data"]["recordHuddlTurnout"]
        assert is_nil(mutation) or is_nil(mutation["result"])
        assert (mutation && mutation["errors"] != []) || json["errors"] != nil
    end

    context
  end

  defp seed_huddl(kind, title, group_name, starts_at) do
    group = find_group(group_name)

    attrs = [
      title: title,
      group_id: group.id,
      creator_id: group.owner_id,
      is_private: false,
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, 2, :hour)
    ]

    generate(past_huddl(attrs ++ kind_attrs(kind)))
  end

  defp kind_attrs("in-person"), do: [event_type: :in_person, virtual_link: nil]

  defp kind_attrs("virtual"),
    do: [event_type: :virtual, physical_location: nil, virtual_link: "https://meet.example.com/x"]

  defp kind_attrs("hybrid"), do: [event_type: :hybrid, virtual_link: "https://meet.example.com/x"]

  defp add_rsvps(huddl, count) do
    for _ <- 1..count//1 do
      attendee = generate(user(role: :user))

      HuddlAttendee
      |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: attendee.id})
      |> Ash.create!(authorize?: false)
    end
  end

  defp remember(context, huddl), do: Map.update(context, :huddlz, [huddl], &[huddl | &1])

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end

  defp record_request(conn, id, "JSON:API", in_room, on_call) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
    |> Phoenix.ConnTest.dispatch(
      HuddlzWeb.Endpoint,
      :patch,
      "/api/json/huddlz/#{id}/record_turnout",
      %{
        "data" => %{
          "type" => "huddl",
          "id" => id,
          "attributes" => %{"in_room" => in_room, "on_call" => on_call}
        }
      }
    )
  end

  defp record_request(conn, id, "GraphQL", in_room, on_call) do
    gql_post(conn, """
    mutation {
      recordHuddlTurnout(id: "#{id}", input: {inRoom: #{in_room}, onCall: #{on_call}}) {
        result { id turnoutInRoom turnoutOnCall showRate }
        errors { message }
      }
    }
    """)
  end

  defp recorded_values(json, "JSON:API") do
    attrs = json["data"]["attributes"]
    {attrs["turnout_in_room"], attrs["turnout_on_call"], attrs["show_rate"]}
  end

  defp recorded_values(json, "GraphQL") do
    assert json["data"]["recordHuddlTurnout"]["errors"] == []
    result = json["data"]["recordHuddlTurnout"]["result"]
    {result["turnoutInRoom"], result["turnoutOnCall"], result["showRate"]}
  end
end
