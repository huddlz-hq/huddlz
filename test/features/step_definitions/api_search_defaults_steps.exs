defmodule ApiSearchDefaultsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, api_key_conn: 2]

  step "I have saved Austin as my home search location", context do
    member = generate(user())

    Huddlz.Accounts.update_home_location!(
      member,
      "Austin, TX",
      30.2672,
      -97.7431,
      "America/Chicago",
      actor: member
    )

    Map.put(context, :defaults_member, member)
  end

  step "I request my search defaults with a bearer token and an API key", context do
    connections = [
      authenticated_conn(context.conn, context.defaults_member),
      api_key_conn(context.conn, context.defaults_member)
    ]

    Map.put(context, :defaults_responses, Enum.map(connections, &get_defaults/1))
  end

  step "both clients receive Austin and a 25 mile default radius", context do
    for response <- context.defaults_responses do
      assert Phoenix.ConnTest.json_response(response, 200)["search_defaults"] == %{
               "home_location" => %{
                 "label" => "Austin, TX",
                 "latitude" => 30.2672,
                 "longitude" => -97.7431,
                 "time_zone" => "America/Chicago"
               },
               "distance_miles" => 25
             }
    end

    context
  end

  defp get_defaults(conn) do
    Phoenix.ConnTest.dispatch(conn, HuddlzWeb.Endpoint, :get, "/api/json/profile", nil)
  end

  step "clients request private profiles with different credentials", context do
    other = generate(user())

    Map.merge(context, %{
      own_profile: context.conn |> authenticated_conn(context.defaults_member) |> get_defaults(),
      other_profile: context.conn |> authenticated_conn(other) |> get_defaults(),
      anonymous_profile: get_defaults(context.conn),
      invalid_profile:
        context.conn
        |> Plug.Conn.put_req_header("authorization", "Bearer invalid")
        |> get_defaults(),
      other_member: other
    })
  end

  step "only my credentials reveal my profile and home search location", context do
    own = Phoenix.ConnTest.json_response(context.own_profile, 200)
    assert own["id"] == context.defaults_member.id
    assert own["email"] == to_string(context.defaults_member.email)
    assert own["display_name"] == context.defaults_member.display_name
    assert own["search_defaults"]["home_location"]["label"] == "Austin, TX"

    other = Phoenix.ConnTest.json_response(context.other_profile, 200)
    assert other["id"] == context.other_member.id
    assert other["search_defaults"]["home_location"] == nil
    assert Phoenix.ConnTest.json_response(context.anonymous_profile, 403)["errors"] != []

    assert Phoenix.ConnTest.json_response(context.invalid_profile, 401)["error"] ==
             "Authentication required"

    context
  end

  step "my home search location is {string}", %{args: [state]} = context do
    member = generate(user())

    location = %{
      home_location: "Austin, TX",
      home_latitude: 30.2672,
      home_longitude: -97.7431,
      home_time_zone: "America/Chicago"
    }

    case state do
      "unset" ->
        :ok

      "cleared" ->
        saved = Ash.Seed.update!(member, location)
        Huddlz.Accounts.update_home_location!(saved, nil, nil, nil, nil, actor: saved)

      "missing latitude" ->
        Ash.Seed.update!(member, %{location | home_latitude: nil})

      "missing longitude" ->
        Ash.Seed.update!(member, %{location | home_longitude: nil})

      "missing time zone" ->
        Ash.Seed.update!(member, %{location | home_time_zone: nil})

      "invalid time zone" ->
        Ash.Seed.update!(member, %{location | home_time_zone: "Invalid/Zone"})
    end

    Map.put(context, :defaults_member, member)
  end

  step "I change my home search location after clients have read my profile", context do
    connections = [
      authenticated_conn(context.conn, context.defaults_member),
      api_key_conn(context.conn, context.defaults_member)
    ]

    for conn <- connections do
      assert Phoenix.ConnTest.json_response(get_defaults(conn), 200)["search_defaults"][
               "home_location"
             ]["label"] == "Austin, TX"
    end

    member = context.defaults_member

    Huddlz.Accounts.update_home_location!(
      member,
      "New York, NY",
      40.7128,
      -74.006,
      "America/New_York",
      actor: member
    )

    Map.put(context, :defaults_responses, Enum.map(connections, &get_defaults/1))
  end

  step "the same clients receive my updated home search location", context do
    for response <- context.defaults_responses do
      assert Phoenix.ConnTest.json_response(response, 200)["search_defaults"]["home_location"] ==
               %{
                 "label" => "New York, NY",
                 "latitude" => 40.7128,
                 "longitude" => -74.006,
                 "time_zone" => "America/New_York"
               }
    end

    context
  end

  step "both clients know there is no usable home search location", context do
    for response <- context.defaults_responses do
      assert Phoenix.ConnTest.json_response(response, 200)["search_defaults"] == %{
               "home_location" => nil,
               "distance_miles" => 25
             }
    end

    context
  end

  step "public huddlz are available in Austin and New York", context do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    for {title, lat, lng} <- [
          {"Austin huddl", 30.2672, -97.7431},
          {"New York huddl", 40.7128, -74.006}
        ] do
      generate(
        huddl_at_location(
          group_id: group.id,
          creator_id: owner.id,
          title: title,
          latitude: lat,
          longitude: lng
        )
      )
    end

    context
  end

  step "I search near home, near New York, and everywhere through the API", context do
    conn = authenticated_conn(context.conn, context.defaults_member)
    defaults = Phoenix.ConnTest.json_response(get_defaults(conn), 200)["search_defaults"]
    home = defaults["home_location"]

    parameters = [
      %{
        "search_latitude" => home["latitude"],
        "search_longitude" => home["longitude"],
        "search_time_zone" => home["time_zone"],
        "distance_miles" => defaults["distance_miles"]
      },
      %{
        "search_latitude" => 40.7128,
        "search_longitude" => -74.006,
        "search_time_zone" => "America/New_York"
      },
      %{}
    ]

    responses =
      for params <- parameters do
        conn
        |> Phoenix.ConnTest.dispatch(
          HuddlzWeb.Endpoint,
          :get,
          "/api/json/huddlz",
          Map.put(params, "date_filter", "upcoming")
        )
        |> Phoenix.ConnTest.json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["attributes"]["title"])
        |> Enum.sort()
      end

    Map.merge(context, %{area_results: responses, defaults_responses: [get_defaults(conn)]})
  end

  step "each search uses the chosen area and my profile still defaults to Austin", context do
    assert context.area_results == [
             ["Austin huddl"],
             ["New York huddl"],
             ["Austin huddl", "New York huddl"]
           ]

    assert Phoenix.ConnTest.json_response(hd(context.defaults_responses), 200)["search_defaults"][
             "home_location"
           ]["label"] == "Austin, TX"

    context
  end
end
