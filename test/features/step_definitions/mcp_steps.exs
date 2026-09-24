defmodule McpSteps do
  use Cucumber.StepDefinition

  alias Huddlz.Test.Helpers.Authentication

  import ExUnit.Assertions
  import Huddlz.Generator

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
          "Bearer " <> context.agent.key
        )
        |> HuddlzWeb.McpCase.json_post("/mcp", %{jsonrpc: "2.0", id: 1, method: "ping"})
      end)

    assert response.status == 429
    assert [_] = Plug.Conn.get_resp_header(response, "retry-after")
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
        HuddlzWeb.McpCase.rpc(context.agent, "tools/call", %{
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
        HuddlzWeb.McpCase.rpc(context.agent, "tools/call", %{
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
      HuddlzWeb.McpCase.rpc(context.agent, "tools/call", %{
        name: "search_huddlz",
        arguments: %{input: %{}}
      })

    assert result["result"]["isError"] == true
    context
  end

  step "my agent sends search arguments outside the input object", context do
    result =
      HuddlzWeb.McpCase.rpc(context.agent, "tools/call", %{
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
    first = HuddlzWeb.McpCase.call(context.agent, "search_huddlz", %{query: "yoga", limit: 1})
    assert first["next_offset"] == 1

    second =
      HuddlzWeb.McpCase.call(context.agent, "search_huddlz", %{query: "yoga", limit: 1, offset: 1})

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
      HuddlzWeb.McpCase.rpc(context.agent, "initialize", %{
        protocolVersion: "2025-06-18",
        capabilities: %{},
        clientInfo: %{name: "acceptance", version: "1"}
      })

    assert response["result"]["protocolVersion"] == "2025-06-18"
    tools = HuddlzWeb.McpCase.rpc(context.agent, "tools/list")["result"]["tools"]

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

  step "my agent discovers and reads the yoga group", context do
    result =
      HuddlzWeb.McpCase.call(context.agent, "search_groups", %{
        query: context.yoga_group.name,
        anywhere: true
      })

    assert Enum.any?(result["items"], &(&1["id"] == context.yoga_group.id))
    group = HuddlzWeb.McpCase.call(context.agent, "get_group", %{slug: context.yoga_group.slug})
    assert group["name"] == to_string(context.yoga_group.name)
    context
  end

  step "I ask my agent to join the yoga group", context do
    result =
      HuddlzWeb.McpCase.call(context.agent, "join_group", %{
        slug: context.yoga_group.slug,
        confirmed: true
      })

    assert result["membership"] == "member"
    context
  end

  step "the yoga group appears in my groups", context do
    result = HuddlzWeb.McpCase.call(context.agent, "my_groups", %{})
    assert Enum.any?(result["items"], &(&1["id"] == context.yoga_group.id))
    context
  end

  step "I ask my agent to leave the yoga group", context do
    result =
      HuddlzWeb.McpCase.call(context.agent, "leave_group", %{
        slug: context.yoga_group.slug,
        confirmed: true
      })

    assert result["membership"] == "none"
    context
  end

  step "the yoga group no longer appears in my groups", context do
    result = HuddlzWeb.McpCase.call(context.agent, "my_groups", %{})
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
      HuddlzWeb.McpCase.call(context.agent, "join_waitlist", %{
        huddl_id: context.yoga.id,
        confirmed: true
      })

    Map.put(context, :tool_result, result)
  end

  step "my agent reports waitlisted rather than confirmed", context do
    assert context.tool_result["attendance_state"] == "waitlisted"
    result = HuddlzWeb.McpCase.call(context.agent, "get_huddl", %{huddl_id: context.yoga.id})
    assert result["attendance_state"] == "waitlisted"
    context
  end

  step "I tell my agent to cancel that RSVP", context do
    result =
      HuddlzWeb.McpCase.call(context.agent, "cancel_rsvp", %{
        huddl_id: context.yoga.id,
        confirmed: true
      })

    assert result["attendance_state"] == "none"
    context
  end

  step "my agent tries to RSVP without my confirmation", context do
    response =
      HuddlzWeb.McpCase.rpc(context.agent, "tools/call", %{
        name: "rsvp_huddl",
        arguments: %{input: %{huddl_id: context.yoga.id, confirmed: false}}
      })

    assert response["result"]["isError"] == true
    context
  end

  step "my attendance is unchanged", context do
    result = HuddlzWeb.McpCase.call(context.agent, "get_huddl", %{huddl_id: context.yoga.id})
    assert result["attendance_state"] == "none"
    context
  end

  step "I tell my agent to sign me up for the nearby yoga huddl", context do
    result =
      HuddlzWeb.McpCase.call(context.agent, "rsvp_huddl", %{
        huddl_id: context.yoga.id,
        confirmed: true
      })

    assert result["attendance_state"] == "confirmed"
    context
  end

  step "my agent can verify my confirmed RSVP", context do
    result = HuddlzWeb.McpCase.call(context.agent, "get_huddl", %{huddl_id: context.yoga.id})
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
      HuddlzWeb.McpCase.call(context.agent, "search_huddlz", %{
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

  step "I connect an agent to my account with an API key", context do
    member = generate(user())

    member =
      Huddlz.Accounts.update_home_location!(
        member,
        "Austin, TX",
        30.2672,
        -97.7431,
        "America/Chicago",
        actor: member
      )

    Map.merge(context, %{mcp_member: member, agent: HuddlzWeb.McpCase.connect(member)})
  end

  step "I connect an agent to my account with a key that has expired", context do
    member = context[:mcp_member] || generate(user())
    agent = HuddlzWeb.McpCase.connect(member, expires_at: DateTime.add(DateTime.utc_now(), -60))
    Map.merge(context, %{mcp_member: member, agent: agent})
  end

  step "I revoke my agent's key", context do
    :ok = Ash.destroy(context.agent.record, actor: context.mcp_member)
    context
  end

  step "an administrator suspends my account", context do
    admin = generate(user(role: :admin))

    Huddlz.Accounts.suspend_user!(context.mcp_member, "Spam", actor: admin)

    context
  end

  step "my agent is refused", context do
    response = HuddlzWeb.McpCase.post_rpc(context.agent, "tools/list")
    assert response.status == 401
    context
  end

  step "I am signed in as a member with a confirmed address", context do
    member = generate(user())
    conn = Authentication.login(context.conn, member)
    session = PhoenixTest.visit(conn, "/")
    Map.merge(context, %{conn: session, session: session, current_user: member})
  end

  step "the guide explains how to add huddlz to Claude Code and Codex CLI", context do
    session =
      context.session
      |> PhoenixTest.assert_has("[role=tabpanel]", text: "claude mcp add --transport http huddlz")
      |> PhoenixTest.assert_has("[role=tabpanel]", text: "HUDDLZ_API_KEY")
      |> PhoenixTest.click_button("Codex CLI")
      |> PhoenixTest.assert_has("[role=tabpanel]", text: "bearer_token_env_var")

    Map.merge(context, %{session: session, conn: session})
  end

  step "my agent asks for my search context", context do
    Map.put(
      context,
      :tool_result,
      HuddlzWeb.McpCase.call(context.agent, "get_search_context", %{})
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

  step "the agent is told to use an API key", context do
    assert context.mcp_response.status == 401
    assert Jason.decode!(context.mcp_response.resp_body)["error"] =~ "API key"
    context
  end
end
