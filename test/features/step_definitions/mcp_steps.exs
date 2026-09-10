defmodule McpSteps do
  alias AshAuthentication.Oauth2Server.Jwt
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  step "I open Help for agent setup", context do
    response = Phoenix.ConnTest.dispatch(context.conn, HuddlzWeb.Endpoint, :get, "/help", nil)
    Map.put(context, :help_html, Phoenix.ConnTest.html_response(response, 200))
  end

  step "Help links to the MCP usage guide", context do
    assert context.help_html =~ "https://github.com/huddlz-hq/huddlz/blob/main/docs/mcp.md"
    context
  end

  step "the MCP rate limits are enabled", context do
    previous = Application.get_env(:huddlz, :rate_limit_enabled)
    Application.put_env(:huddlz, :rate_limit_enabled, true)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:huddlz, :rate_limit_enabled, previous)
    end)

    context
  end

  step "repeated agent calls receive a retry delay", context do
    response =
      Enum.reduce(1..121, nil, fn _, _ ->
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header(
          "authorization",
          "Bearer " <> context.oauth.tokens["access_token"]
        )
        |> HuddlzWeb.McpCase.json_post("/mcp", %{jsonrpc: "2.0", id: 1, method: "ping"})
      end)

    assert response.status == 429
    assert [_] = Plug.Conn.get_resp_header(response, "retry-after")
    context
  end

  step "repeated client registrations receive a retry delay", context do
    response =
      Enum.reduce(1..11, nil, fn _, _ ->
        conn = %{Phoenix.ConnTest.build_conn() | remote_ip: {192, 0, 2, 101}}

        HuddlzWeb.McpCase.json_post(conn, "/oauth/register", %{
          client_name: "rate test",
          redirect_uris: ["http://127.0.0.1:54321/callback"]
        })
      end)

    assert response.status == 429
    assert [_] = Plug.Conn.get_resp_header(response, "retry-after")
    context
  end

  step "website tokens, API keys, expired tokens, and missing scopes cannot call MCP", context do
    {:ok, expired, _} =
      Jwt.mint(Huddlz.Oauth2Server,
        sub: context.mcp_member.id,
        client_id: context.oauth.client_id,
        scope: "mcp",
        ttl: -60
      )

    {:ok, unscoped, _} =
      Jwt.mint(Huddlz.Oauth2Server,
        sub: context.mcp_member.id,
        client_id: context.oauth.client_id,
        scope: ""
      )

    for {conn, status} <- [
          {HuddlzWeb.ApiCase.authenticated_conn(context.conn, context.mcp_member), 401},
          {HuddlzWeb.ApiCase.api_key_conn(context.conn, context.mcp_member), 401},
          {Plug.Conn.put_req_header(context.conn, "authorization", "Bearer " <> expired), 401},
          {Plug.Conn.put_req_header(context.conn, "authorization", "Bearer " <> unscoped), 403}
        ] do
      response =
        HuddlzWeb.McpCase.json_post(conn, "/mcp", %{jsonrpc: "2.0", id: 1, method: "tools/list"})

      assert response.status == status
    end

    context
  end

  step "invalid search arguments receive tool errors", context do
    for args <- [
          %{limit: 51},
          %{offset: -1},
          %{latitude: 200},
          %{latitude: 30},
          %{user_id: context.mcp_member.id},
          %{starts_before: "tomorrow"},
          %{starts_at_or_after: "2030-01-02T00:00:00Z", starts_before: "2030-01-01T00:00:00Z"}
        ] do
      result =
        HuddlzWeb.McpCase.rpc(context.oauth, "tools/call", %{
          name: "search_huddlz",
          arguments: %{input: args}
        })

      assert result["result"]["isError"] == true, inspect(args)
    end

    context
  end

  step "another person's private huddl cannot be read or joined", context do
    private =
      generate(
        huddl_at_location(
          group_id: context.yoga_group.id,
          creator_id: context.yoga_group.owner_id,
          title: "Private yoga",
          is_private: true
        )
      )

    for name <- ["get_huddl", "rsvp_huddl"] do
      args =
        if name == "get_huddl",
          do: %{huddl_id: private.id},
          else: %{huddl_id: private.id, confirmed: true}

      result =
        HuddlzWeb.McpCase.rpc(context.oauth, "tools/call", %{
          name: name,
          arguments: %{input: args}
        })

      assert result["result"]["isError"] == true
      refute inspect(result) =~ "Private yoga"
    end

    context
  end

  step "a member without a home location must choose a search location", context do
    Huddlz.Accounts.update_home_location!(context.mcp_member, nil, nil, nil, nil,
      actor: context.mcp_member
    )

    result =
      HuddlzWeb.McpCase.rpc(context.oauth, "tools/call", %{
        name: "search_huddlz",
        arguments: %{input: %{}}
      })

    assert result["result"]["isError"] == true
    context
  end

  step "my agent sends search arguments outside the input object", context do
    result =
      HuddlzWeb.McpCase.rpc(context.oauth, "tools/call", %{
        name: "search_huddlz",
        arguments: %{query: "yoga"}
      })

    Map.put(context, :mcp_rpc_result, result)
  end

  step "it receives a useful tool error", context do
    assert context.mcp_rpc_result["result"]["isError"] == true
    assert inspect(context.mcp_rpc_result["result"]["content"]) =~ "input"
    context
  end

  step "my agent can page through huddlz without duplicates", context do
    first = HuddlzWeb.McpCase.call(context.oauth, "search_huddlz", %{query: "yoga", limit: 1})
    assert first["next_offset"] == 1

    second =
      HuddlzWeb.McpCase.call(context.oauth, "search_huddlz", %{query: "yoga", limit: 1, offset: 1})

    assert second["next_offset"] == nil
    [a] = first["items"]
    [b] = second["items"]
    assert a["title"] == "Evening yoga"
    assert b["title"] == "Tomorrow yoga"
    refute a["id"] == b["id"]
    context
  end

  step "its tool catalog contains only the agreed tools with described arguments", context do
    response =
      HuddlzWeb.McpCase.rpc(context.oauth, "initialize", %{
        protocolVersion: "2025-06-18",
        capabilities: %{},
        clientInfo: %{name: "acceptance", version: "1"}
      })

    assert response["result"]["protocolVersion"] == "2025-06-18"
    tools = HuddlzWeb.McpCase.rpc(context.oauth, "tools/list")["result"]["tools"]

    assert Enum.map(tools, & &1["name"]) ==
             Enum.sort(
               ~w(cancel_rsvp get_group get_huddl get_search_context join_group join_waitlist leave_group my_groups rsvp_huddl search_groups search_huddlz)
             )

    for tool <- tools do
      assert String.length(tool["description"]) > 20

      for {_key, schema} <-
            get_in(tool, ["inputSchema", "properties", "input", "properties"]) || %{} do
        assert is_binary(schema["description"])
      end
    end

    context
  end

  step "its authorization code cannot be reused", context do
    response =
      HuddlzWeb.McpCase.json_post(context.conn, "/oauth/token", context.oauth.token_params)

    assert Phoenix.ConnTest.json_response(response, 400)["error"] == "invalid_grant"
    context
  end

  step "its refresh token rotates and can be revoked", context do
    params = %{
      grant_type: "refresh_token",
      client_id: context.oauth.client_id,
      refresh_token: context.oauth.tokens["refresh_token"],
      resource: Huddlz.Oauth2Server.resource_url()
    }

    response = HuddlzWeb.McpCase.json_post(context.conn, "/oauth/token", params)
    assert Plug.Conn.get_resp_header(response, "cache-control") == ["no-store"]
    rotated = Phoenix.ConnTest.json_response(response, 200)
    refute rotated["refresh_token"] == params.refresh_token
    assert rotated["access_token"]

    revoke =
      HuddlzWeb.McpCase.json_post(context.conn, "/oauth/revoke", %{
        client_id: context.oauth.client_id,
        token: rotated["refresh_token"]
      })

    assert revoke.status == 200

    denied =
      HuddlzWeb.McpCase.json_post(context.conn, "/oauth/token", %{
        params
        | refresh_token: rotated["refresh_token"]
      })

    assert Phoenix.ConnTest.json_response(denied, 400)["error"] == "invalid_grant"
    context
  end

  step "my agent discovers and reads the yoga group", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "search_groups", %{
        query: context.yoga_group.name,
        anywhere: true
      })

    assert Enum.any?(result["items"], &(&1["id"] == context.yoga_group.id))
    group = HuddlzWeb.McpCase.call(context.oauth, "get_group", %{slug: context.yoga_group.slug})
    assert group["name"] == to_string(context.yoga_group.name)
    context
  end

  step "I ask my agent to join the yoga group", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "join_group", %{
        slug: context.yoga_group.slug,
        confirmed: true
      })

    assert result["membership"] == "member"
    context
  end

  step "the yoga group appears in my groups", context do
    result = HuddlzWeb.McpCase.call(context.oauth, "my_groups", %{})
    assert Enum.any?(result["items"], &(&1["id"] == context.yoga_group.id))
    context
  end

  step "I ask my agent to leave the yoga group", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "leave_group", %{
        slug: context.yoga_group.slug,
        confirmed: true
      })

    assert result["membership"] == "none"
    context
  end

  step "the yoga group no longer appears in my groups", context do
    result = HuddlzWeb.McpCase.call(context.oauth, "my_groups", %{})
    refute Enum.any?(result["items"], &(&1["id"] == context.yoga_group.id))
    context
  end

  step "the nearby yoga huddl is full", context do
    yoga = Ash.Seed.update!(context.yoga, %{max_attendees: 1})
    owner = Ash.get!(Huddlz.Accounts.User, context.yoga_group.owner_id, authorize?: false)
    Huddlz.Communities.rsvp_huddl!(yoga, %{}, actor: owner)
    context
  end

  step "I ask my agent to join its waitlist", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "join_waitlist", %{
        huddl_id: context.yoga.id,
        confirmed: true
      })

    Map.put(context, :tool_result, result)
  end

  step "my agent reports waitlisted rather than confirmed", context do
    assert context.tool_result["attendance_state"] == "waitlisted"
    result = HuddlzWeb.McpCase.call(context.oauth, "get_huddl", %{huddl_id: context.yoga.id})
    assert result["attendance_state"] == "waitlisted"
    context
  end

  step "I tell my agent to cancel that RSVP", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "cancel_rsvp", %{
        huddl_id: context.yoga.id,
        confirmed: true
      })

    assert result["attendance_state"] == "none"
    context
  end

  step "my agent tries to RSVP without my confirmation", context do
    response =
      HuddlzWeb.McpCase.rpc(context.oauth, "tools/call", %{
        name: "rsvp_huddl",
        arguments: %{input: %{huddl_id: context.yoga.id, confirmed: false}}
      })

    assert response["result"]["isError"] == true
    context
  end

  step "my attendance is unchanged", context do
    result = HuddlzWeb.McpCase.call(context.oauth, "get_huddl", %{huddl_id: context.yoga.id})
    assert result["attendance_state"] == "none"
    context
  end

  step "I tell my agent to sign me up for the nearby yoga huddl", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "rsvp_huddl", %{
        huddl_id: context.yoga.id,
        confirmed: true
      })

    assert result["attendance_state"] == "confirmed"
    context
  end

  step "my agent can verify my confirmed RSVP", context do
    result = HuddlzWeb.McpCase.call(context.oauth, "get_huddl", %{huddl_id: context.yoga.id})
    assert result["attendance_state"] == "confirmed"
    context
  end

  step "yoga huddlz are scheduled near home, far away, and outside the evening", context do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    date = Date.add(Date.utc_today(), 2)
    from = DateTime.new!(date, ~T[18:00:00], "America/Chicago") |> DateTime.shift_zone!("Etc/UTC")
    until = DateTime.add(from, 6, :hour)

    nearby =
      generate(
        huddl_at_location(
          group_id: group.id,
          creator_id: owner.id,
          title: "Evening yoga",
          latitude: 30.2672,
          longitude: -97.7431,
          starts_at: DateTime.add(from, 1, :hour),
          ends_at: DateTime.add(from, 2, :hour)
        )
      )

    generate(
      huddl_at_location(
        group_id: group.id,
        creator_id: owner.id,
        title: "Distant yoga",
        latitude: 40.7128,
        longitude: -74.006,
        starts_at: DateTime.add(from, 1, :hour),
        ends_at: DateTime.add(from, 2, :hour)
      )
    )

    generate(
      huddl_at_location(
        group_id: group.id,
        creator_id: owner.id,
        title: "Tomorrow yoga",
        latitude: 30.2672,
        longitude: -97.7431,
        starts_at: until,
        ends_at: DateTime.add(until, 2, :hour)
      )
    )

    generate(
      huddl_at_location(
        group_id: group.id,
        creator_id: owner.id,
        title: "Private yoga",
        is_private: true,
        latitude: 30.2672,
        longitude: -97.7431,
        starts_at: DateTime.add(from, 1, :hour),
        ends_at: DateTime.add(from, 2, :hour)
      )
    )

    Map.merge(context, %{
      yoga: nearby,
      yoga_group: group,
      evening_from: from,
      evening_until: until
    })
  end

  step "my agent searches for yoga during that evening", context do
    result =
      HuddlzWeb.McpCase.call(context.oauth, "search_huddlz", %{
        query: "yoga",
        starts_at_or_after: DateTime.to_iso8601(context.evening_from),
        starts_before: DateTime.to_iso8601(context.evening_until)
      })

    Map.put(context, :tool_result, result)
  end

  step "it receives only the nearby yoga huddl within that evening", context do
    assert [%{"id" => id, "title" => "Evening yoga", "attendance_state" => "none"}] =
             context.tool_result["items"]

    assert id == context.yoga.id
    assert context.tool_result["next_offset"] == nil
    context
  end

  step "I connect an agent to my account using OAuth", context do
    member = generate(user(hashed_password: Bcrypt.hash_pwd_salt("McpTestPassword321!")))

    member =
      Huddlz.Accounts.update_home_location!(
        member,
        "Austin, TX",
        30.2672,
        -97.7431,
        "America/Chicago",
        actor: member
      )

    oauth = HuddlzWeb.McpCase.connect(context.conn, member)
    Map.merge(context, %{mcp_member: member, oauth: oauth})
  end

  step "my agent asks for my search context", context do
    Map.put(
      context,
      :tool_result,
      HuddlzWeb.McpCase.call(context.oauth, "get_search_context", %{})
    )
  end

  step "it receives my home search location without my email address", context do
    result = context.tool_result
    assert result["home_location"]["label"] == "Austin, TX"
    assert result["home_location"]["time_zone"] == "America/Chicago"
    assert result["distance_miles"] == 25
    refute Map.has_key?(result, "email")
    context
  end

  step "an anonymous agent searches for huddlz", context do
    response =
      context.conn
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Phoenix.ConnTest.dispatch(
        HuddlzWeb.Endpoint,
        :post,
        "/mcp",
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{name: "search_huddlz", arguments: %{}}
        })
      )

    Map.put(context, :mcp_response, response)
  end

  step "the agent is directed to connect with OAuth", context do
    assert context.mcp_response.status == 401
    [challenge] = Plug.Conn.get_resp_header(context.mcp_response, "www-authenticate")
    assert challenge =~ "resource_metadata="
    assert challenge =~ "oauth-protected-resource"
    context
  end
end
