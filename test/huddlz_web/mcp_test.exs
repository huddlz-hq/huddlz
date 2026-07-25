defmodule HuddlzWeb.MCPTest do
  use HuddlzWeb.ApiCase, async: false

  alias Huddlz.Accounts.ApiKey

  @protocol_version "2025-11-25"

  setup do
    Mox.set_mox_global()
    stub_geocode(%{latitude: 30.27, longitude: -97.74})
    :ok
  end

  describe "Streamable HTTP lifecycle" do
    test "initializes, advertises tools, and closes a session" do
      {session_id, _initialize} = initialize()

      assert response =
               session_id
               |> tool_request("tools/list")
               |> json_response(200)

      names = Enum.map(response["result"]["tools"], & &1["name"])
      assert "search_groups" in names
      assert "rsvp_huddl" in names
      assert "create_huddl" in names

      assert close_session(session_id).status == 200
    end

    test "rejects cross-origin browser requests" do
      conn =
        build_conn()
        |> put_req_header("origin", "https://attacker.example")
        |> mcp_post(initialize_message())

      assert %{"error" => %{"message" => "Forbidden"}} = json_response(conn, 403)
    end

    test "requires the initialized principal for every later session request" do
      user_a = generate(user(role: :user))
      user_b = generate(user(role: :user))
      {_key_a, bearer_a} = mint_api_key(user_a)
      {_key_b, bearer_b} = mint_api_key(user_b)

      {session_id, _initialize} = initialize(bearer_a)

      conn = tool_request(session_id, "tools/list", %{}, bearer_b)

      assert %{"error" => %{"data" => message}} = json_response(conn, 403)
      assert message =~ "different principal"

      close_session(session_id, bearer_a)
    end
  end

  describe "public and authenticated reads" do
    test "anonymous discovery returns public groups with opaque pagination" do
      owner = generate(user(role: :user))

      for name <- ["MCP Alpha", "MCP Beta"] do
        generate(group(name: name, is_public: true, actor: owner))
      end

      generate(group(name: "MCP Private", is_public: false, actor: owner))

      {session_id, _initialize} = initialize()

      first =
        session_id
        |> tool_request("search_groups", %{"search" => "MCP", "limit" => 1})
        |> tool_result()

      assert length(first["items"]) == 1
      assert is_binary(first["next_cursor"])
      assert first["total_count"] == 2

      second =
        session_id
        |> tool_request("search_groups", %{
          "search" => "MCP",
          "limit" => 1,
          "cursor" => first["next_cursor"]
        })
        |> tool_result()

      assert length(second["items"]) == 1
      refute Enum.any?(first["items"] ++ second["items"], &(&1["name"] == "MCP Private"))

      close_session(session_id)
    end

    test "private group details require an authorized bearer credential" do
      owner = generate(user(role: :user))
      group = generate(group(name: "Private MCP Group", is_public: false, actor: owner))

      {anonymous_session, _initialize} = initialize()

      anonymous =
        anonymous_session
        |> tool_request("get_group", %{"slug" => group.slug})
        |> json_response(200)

      assert anonymous["result"]["isError"] == true

      {_key, bearer} = mint_api_key(owner)
      {owner_session, _initialize} = initialize(bearer)

      result =
        owner_session
        |> tool_request("get_group", %{"slug" => group.slug}, bearer)
        |> tool_result()

      assert result["group"]["slug"] == group.slug

      close_session(anonymous_session)
      close_session(owner_session, bearer)
    end

    test "authenticated tools fail after the API key is revoked" do
      user = generate(user(role: :user))
      {api_key, bearer} = mint_api_key(user)
      {session_id, _initialize} = initialize(bearer)

      :ok = Ash.destroy!(api_key, actor: user)

      conn =
        tool_request(
          session_id,
          "list_my_groups",
          %{"relationship" => "all"},
          bearer
        )

      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end

  describe "write tool safety and Ash authorization" do
    test "write tools require explicit confirmation and authentication" do
      {anonymous_session, _initialize} = initialize()

      unauthenticated =
        anonymous_session
        |> tool_request("join_group", %{"slug" => "anything", "confirm" => true})
        |> tool_result_envelope()

      assert unauthenticated["isError"] == true
      assert decode_text(unauthenticated)["error"] == "authentication_required"

      user = generate(user(role: :user))
      {_key, bearer} = mint_api_key(user)
      {session_id, _initialize} = initialize(bearer)

      unconfirmed =
        session_id
        |> tool_request(
          "create_group",
          %{
            "name" => "Unconfirmed",
            "description" => "No",
            "location" => "Austin",
            "is_public" => true
          },
          bearer
        )
        |> json_response(200)

      assert unconfirmed["error"]["code"] == -32_602
      assert unconfirmed["error"]["message"] =~ "confirm must be true"

      close_session(anonymous_session)
      close_session(session_id, bearer)
    end

    test "an authenticated person can create a group and join another public group" do
      owner = generate(user(role: :user))
      joiner = generate(user(role: :user))
      public_group = generate(group(name: "Joinable MCP", is_public: true, actor: owner))

      {_key, bearer} = mint_api_key(joiner)
      {session_id, _initialize} = initialize(bearer)

      created =
        session_id
        |> tool_request(
          "create_group",
          %{
            "name" => "Created over MCP",
            "description" => "A protocol-created group",
            "location" => "Austin",
            "is_public" => true,
            "confirm" => true
          },
          bearer
        )
        |> tool_result()

      assert created["group"]["name"] == "Created over MCP"

      joined =
        session_id
        |> tool_request(
          "join_group",
          %{
            "slug" => public_group.slug,
            "confirm" => true
          },
          bearer
        )
        |> tool_result()

      assert joined["membership"]["role"] == "member"
      assert joined["group"]["slug"] == public_group.slug

      close_session(session_id, bearer)
    end

    test "organizer creation and attendee RSVP changes use the existing Ash actions" do
      owner = generate(user(role: :user))
      attendee = generate(user(role: :user))
      group = generate(group(name: "MCP RSVP Group", is_public: true, actor: owner))

      {_owner_key, owner_bearer} = mint_api_key(owner)
      {owner_session, _initialize} = initialize(owner_bearer)

      huddl_conn =
        owner_session
        |> tool_request(
          "create_huddl",
          %{
            "group_slug" => group.slug,
            "title" => "MCP RSVP Huddl",
            "description" => "Created through the MCP contract",
            "date" => Date.utc_today() |> Date.add(7) |> Date.to_iso8601(),
            "start_time" => "18:30",
            "duration_minutes" => 60,
            "event_type" => "in_person",
            "physical_location" => "123 MCP Street",
            "is_private" => false,
            "confirm" => true
          },
          owner_bearer
        )

      huddl_result = tool_result(huddl_conn)

      huddl_id = huddl_result["huddl"]["id"]
      assert huddl_result["huddl"]["title"] == "MCP RSVP Huddl"

      {_attendee_key, attendee_bearer} = mint_api_key(attendee)
      {attendee_session, _initialize} = initialize(attendee_bearer)

      rsvp =
        attendee_session
        |> tool_request(
          "rsvp_huddl",
          %{"huddl_id" => huddl_id, "confirm" => true},
          attendee_bearer
        )
        |> tool_result()

      assert rsvp["outcome"] == "rsvped"

      cancellation =
        attendee_session
        |> tool_request(
          "cancel_huddl_rsvp",
          %{"huddl_id" => huddl_id, "confirm" => true},
          attendee_bearer
        )
        |> tool_result()

      assert cancellation["outcome"] == "cancelled"

      close_session(owner_session, owner_bearer)
      close_session(attendee_session, attendee_bearer)
    end
  end

  describe "request validation and rate limits" do
    test "rejects malformed pagination cursors as invalid params" do
      {session_id, _initialize} = initialize()

      response =
        session_id
        |> tool_request("search_groups", %{"cursor" => "not-base64!"})
        |> json_response(200)

      assert response["error"]["code"] == -32_602
      assert response["error"]["message"] =~ "cursor"

      close_session(session_id)
    end

    test "returns 429 and Retry-After when the MCP request bucket is exhausted" do
      previous_enabled = Application.get_env(:huddlz, :rate_limit_enabled)
      previous_limits = Application.fetch_env!(:huddlz, :mcp_rate_limits)

      on_exit(fn ->
        Application.put_env(:huddlz, :rate_limit_enabled, previous_enabled)
        Application.put_env(:huddlz, :mcp_rate_limits, previous_limits)
      end)

      Application.put_env(:huddlz, :rate_limit_enabled, true)
      Application.put_env(:huddlz, :mcp_rate_limits, authenticated: 1, anonymous: 1, per: 60_000)

      first = mcp_post(build_conn(), initialize_message())
      assert first.status == 200

      second = mcp_post(build_conn(), initialize_message())
      assert second.status == 429
      assert get_resp_header(second, "retry-after") != []
      assert json_response(second, 429)["error"]["message"] == "Too many requests"
    end
  end

  defp initialize(bearer \\ nil) do
    conn =
      build_conn()
      |> maybe_authorize(bearer)
      |> mcp_post(initialize_message())

    response = json_response(conn, 200)
    assert response["result"]["protocolVersion"] == @protocol_version
    [session_id] = get_resp_header(conn, "mcp-session-id")

    initialized_conn =
      build_conn()
      |> maybe_authorize(bearer)
      |> put_req_header("mcp-session-id", session_id)
      |> mcp_post(%{"jsonrpc" => "2.0", "method" => "notifications/initialized"})

    assert initialized_conn.status == 202
    {session_id, response}
  end

  defp initialize_message do
    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => @protocol_version,
        "capabilities" => %{},
        "clientInfo" => %{"name" => "huddlz-test", "version" => "1.0.0"}
      }
    }
  end

  defp tool_request(session_id, method, arguments \\ %{}, bearer \\ nil)

  defp tool_request(session_id, "tools/list", _arguments, bearer) do
    build_conn()
    |> maybe_authorize(bearer)
    |> put_req_header("mcp-session-id", session_id)
    |> mcp_post(%{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"})
  end

  defp tool_request(session_id, name, arguments, bearer) do
    build_conn()
    |> maybe_authorize(bearer)
    |> put_req_header("mcp-session-id", session_id)
    |> mcp_post(%{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/call",
      "params" => %{"name" => name, "arguments" => arguments}
    })
  end

  defp close_session(session_id, bearer \\ nil) do
    build_conn()
    |> maybe_authorize(bearer)
    |> put_req_header("mcp-session-id", session_id)
    |> put_req_header("mcp-protocol-version", @protocol_version)
    |> delete("/mcp")
  end

  defp mcp_post(conn, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", @protocol_version)
    |> post("/mcp", Jason.encode!(body))
  end

  defp tool_result(conn) do
    conn
    |> tool_result_envelope()
    |> decode_text()
  end

  defp tool_result_envelope(conn) do
    response = json_response(conn, 200)
    response["result"]
  end

  defp decode_text(result) do
    result
    |> get_in(["content", Access.at(0), "text"])
    |> Jason.decode!()
  end

  defp mint_api_key(user) do
    record =
      ApiKey
      |> Ash.Changeset.for_create(
        :create,
        %{expires_at: DateTime.add(DateTime.utc_now(), 7, :day)},
        actor: user
      )
      |> Ash.create!()

    {record, "Bearer " <> record.__metadata__.plaintext_api_key}
  end

  defp maybe_authorize(conn, nil), do: conn
  defp maybe_authorize(conn, bearer), do: put_req_header(conn, "authorization", bearer)
end
