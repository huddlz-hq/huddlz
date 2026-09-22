defmodule SocialConnectionsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]

  import Phoenix.ConnTest,
    only: [build_conn: 0, dispatch: 4, dispatch: 5, json_response: 2, redirected_to: 1]

  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.SocialConnection

  # Connecting hands off to the platform's own consent screen and comes back
  # to huddlz with a code. The hand-off is followed by hand here: the redirect
  # to the platform is read for its state, the platform's answer is stubbed,
  # and the callback is requested the way the platform would.
  step "I connect the {word} channel {string} of {string} from the Social tab of {string}",
       %{args: [platform, channel, workspace, group_name]} = context do
    group = lookup_group(group_name)
    kind = platform |> String.downcase() |> String.to_existing_atom()
    session = visit(context.session, "/organize/#{group.slug}/social")

    session
    |> click_button("Connect a place")
    |> assert_has("a", text: platform)

    Req.Test.stub(Huddlz.Social, fn conn ->
      Req.Test.json(conn, platform_answer(kind, workspace, channel))
    end)

    session = follow_platform_handoff(session, group, kind)

    session =
      session
      |> check("A week before")
      |> check("The morning of")
      |> click_button("Start posting")

    Map.merge(context, %{session: session, conn: session, group: group})
  end

  step "the Social tab lists a connection to {string} on {word}",
       %{args: [channel, platform]} = context do
    assert_has(context.session, "#social-connections [id^='social-connection-']", text: channel)
    assert_has(context.session, "#social-connections [id^='social-connection-']", text: platform)
    context
  end

  step "the connection shows as posting", context do
    assert_has(context.session, "#social-connections [id^='social-connection-']", text: "Posting")
    context
  end

  step "the activity of {string} says {string}", %{args: [group_name, line]} = context do
    group = lookup_group(group_name)

    context.session
    |> visit("/organize/#{group.slug}")
    |> assert_has("#recent-activity", text: line)

    context
  end

  step "I send a test post to {string} from the Social tab of {string}",
       %{args: [channel, group_name]} = context do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:webhook_received, conn.body_params})
      Req.Test.json(conn, %{"ok" => true})
    end)

    session =
      context
      |> open_connection(channel, group_name)
      |> click_button("Send a test post")

    Map.merge(context, %{session: session, conn: session})
  end

  step "that channel receives a message saying it is a test from huddlz for {string}",
       %{args: [group_name]} = context do
    assert_receive {:webhook_received, %{"text" => text}}, 1_000
    assert text =~ "test from huddlz"
    assert text =~ group_name
    context
  end

  step "I change the opening line of {string} to {string} from the Social tab of {string}",
       %{args: [channel, line, group_name]} = context do
    session =
      context
      |> open_connection(channel, group_name)
      |> fill_in("Opening line", with: line)

    Map.merge(context, %{session: session, conn: session})
  end

  step "the connection to {string} opens with {string} without a save button",
       %{args: [channel, line]} = context do
    refute_has(context.session, "#schedule-form button[type='submit']", text: "Save")

    context.session
    |> visit("/organize/#{context.group.slug}/social")
    |> assert_has("#social-connections [id^='social-connection-']", text: channel)
    |> assert_has("#social-connections [id^='social-connection-']", text: line)

    context
  end

  step "I pause {string} from the Social tab of {string}",
       %{args: [_channel, group_name]} = context do
    group = lookup_group(group_name)

    session =
      context.session
      |> visit("/organize/#{group.slug}/social")
      |> within("#social-connections", fn row -> click_button(row, "Pause") end)

    Map.merge(context, %{session: session, conn: session, group: group})
  end

  step "the connection shows as paused", context do
    assert_has(context.session, "#social-connections [id^='social-connection-']", text: "Paused")
    context
  end

  step "I open the Social tab of {string}", %{args: [group_name]} = context do
    group = lookup_group(group_name)
    session = visit(context.session, "/organize/#{group.slug}/social")
    Map.merge(context, %{session: session, conn: session, group: group})
  end

  step "I can see the connection to {string} but cannot change its schedule or remove it",
       %{args: [channel]} = context do
    context.session
    |> assert_has("#social-connections [id^='social-connection-']", text: channel)
    |> refute_has("#social-connections button", text: "Edit")
    |> refute_has("button", text: "Remove")

    context
  end

  step "the API refuses my attempt to remove it", context do
    response =
      gql(
        context.current_user,
        """
        mutation($id: ID!) { removeSocialConnection(id: $id) { result { id } errors { code message } } }
        """,
        %{"id" => context.connection.id}
      )

    assert refused?(response["data"]["removeSocialConnection"], response["errors"]),
           "expected the removal to be refused, got #{inspect(response)}"

    assert Ash.get!(Huddlz.Communities.SocialConnection, context.connection.id, authorize?: false)
    context
  end

  step "I cannot see the social connections of {string} on the site or the API",
       %{args: [group_name]} = context do
    group = lookup_group(group_name)

    context.session
    |> visit("/organize/#{group.slug}/social")
    |> refute_has("#social-connections")
    |> refute_has("*", text: "#general")

    response =
      gql(
        context.current_user,
        """
        query($groupId: ID!) { socialConnections(groupId: $groupId) { id channelName } }
        """,
        %{"groupId" => group.id}
      )

    assert response["errors"] == nil, inspect(response)
    assert response["data"]["socialConnections"] == []
    context
  end

  step "I remove {string} from the Social tab of {string} and confirm",
       %{args: [channel, group_name]} = context do
    session =
      context
      |> open_connection(channel, group_name)
      |> click_button("Remove")
      |> within("#remove-connection-dialog", fn dialog ->
        click_button(dialog, "Remove connection")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  step "the Social tab of {string} lists no social connections",
       %{args: [group_name]} = context do
    group = lookup_group(group_name)

    context.session
    |> visit("/organize/#{group.slug}/social")
    |> assert_has("#social-connections", text: "Nothing connected yet")
    |> refute_has("#social-connections [id^='social-connection-']")

    context
  end

  step "ownership of {string} passes to {string}", %{args: [group_name, email]} = context do
    group = lookup_group(group_name) |> Ash.load!(:owner, authorize?: false)
    new_owner = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

    group
    |> Ash.Changeset.for_update(:transfer_ownership, %{new_owner_id: new_owner.id},
      actor: group.owner
    )
    |> Ash.update!()

    context
  end

  step "I can change the schedule of {string} and remove it", %{args: [channel]} = context do
    session =
      context.session
      |> within("#social-connections", fn list -> click_button(list, "Edit") end)
      |> assert_has("#schedule-sheet", text: channel)
      |> assert_has("#schedule-sheet button", text: "Remove")

    Map.merge(context, %{session: session, conn: session})
  end

  step "the connection still says it was connected by {string}", %{args: [name]} = context do
    context.session
    |> visit("/organize/#{context.group.slug}/social")
    |> assert_has("#social-connections [id^='social-connection-']", text: "connected by #{name}")

    context
  end

  step "the Social tab explains that only public groups post", context do
    context.session
    |> assert_has("#social-private-note", text: "Only public groups post")
    |> refute_has("button", text: "Connect a place")

    context
  end

  step "the API refuses a connection for {string}", %{args: [group_name]} = context do
    group = lookup_group(group_name)

    response =
      gql(
        context.current_user,
        """
        mutation($input: ConnectPlaceInput!) {
          connectPlace(input: $input) { result { id } errors { code message } }
        }
        """,
        %{
          "input" => %{
            "groupId" => group.id,
            "kind" => "SLACK",
            "workspaceName" => "Inner Circle HQ",
            "channelName" => "#private",
            "webhookUrl" => "https://hooks.slack.com/services/T000/B000/private"
          }
        }
      )

    assert refused?(response["data"]["connectPlace"], response["errors"]),
           "expected the connection to be refused, got #{inspect(response)}"

    context
  end

  step "I read the social connections of {string} through the API",
       %{args: [group_name]} = context do
    group = lookup_group(group_name)

    response =
      gql(
        context.current_user,
        """
        query($groupId: ID!) {
          socialConnections(groupId: $groupId) { id kind channelName workspaceName moments state }
          __type(name: "SocialConnection") { fields { name } }
        }
        """,
        %{"groupId" => group.id}
      )

    Map.put(context, :api_response, response)
  end

  step "the response names {string} but carries no webhook address",
       %{args: [channel]} = context do
    response = context.api_response
    assert [%{"channelName" => ^channel}] = response["data"]["socialConnections"]

    fields = Enum.map(response["data"]["__type"]["fields"], & &1["name"])
    refute Enum.any?(fields, &(&1 =~ ~r/webhook/i)), "the API type exposes #{inspect(fields)}"
    refute Jason.encode!(response) =~ "hooks.slack.com"
    context
  end

  step "I try to connect a {word} place at {string} through the API",
       %{args: [kind, address]} = context do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, :destination_contacted)
      Req.Test.json(conn, %{})
    end)

    group = lookup_group("Elixir Nashville")

    response =
      gql(
        context.current_user,
        """
        mutation($input: ConnectPlaceInput!) {
          connectPlace(input: $input) { result { id } errors { code message } }
        }
        """,
        %{
          "input" => %{
            "groupId" => group.id,
            "kind" => kind,
            "workspaceName" => "A place",
            "channelName" => "#general",
            "webhookUrl" => address
          }
        }
      )

    Map.put(context, :api_response, response)
  end

  step "the API refuses the destination without contacting it", context do
    response = context.api_response
    assert refused?(response["data"]["connectPlace"], response["errors"]), inspect(response)
    refute_receive :destination_contacted
    context
  end

  step "the platform redirects a test post to another address", context do
    test = self()

    Req.Test.stub(Huddlz.Social, fn
      %{host: "hooks.slack.com"} = conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://127.0.0.1/internal")
        |> Plug.Conn.resp(307, "")

      conn ->
        send(test, :redirect_contacted)
        Req.Test.json(conn, %{})
    end)

    result =
      Huddlz.Communities.send_social_test_post(context.connection.id, actor: context.current_user)

    Map.put(context, :post_result, result)
  end

  step "the test post fails without contacting the redirected address", context do
    assert {:error, _} = context.post_result
    refute_receive :redirect_contacted
    context
  end

  step "I connect places through both APIs with diagnostic logging enabled", context do
    group = lookup_group("Elixir Nashville")
    secret = "diagnostic-secret-marker"
    url = "https://hooks.slack.com/services/T000/B000/" <> secret
    previous_level = Logger.level()
    Logger.configure(level: :debug)
    on_exit = fn -> Logger.configure(level: previous_level) end
    ExUnit.Callbacks.on_exit(on_exit)

    log =
      ExUnit.CaptureLog.capture_log([level: :debug], fn ->
        Logger.put_process_level(self(), :debug)

        try do
          response =
            gql(
              context.current_user,
              """
              mutation($input: ConnectPlaceInput!) {
                connectPlace(input: $input) { result { id } errors { message } }
              }
              """,
              %{
                "input" => %{
                  "groupId" => group.id,
                  "kind" => "SLACK",
                  "workspaceName" => "Workspace",
                  "channelName" => "#general",
                  "webhookUrl" => url
                }
              }
            )

          assert %{"data" => %{"connectPlace" => %{"result" => %{"id" => _}}}} = response

          response =
            gql(
              context.current_user,
              """
              mutation { connectPlace(input: {groupId: "#{group.id}", kind: SLACK,
                workspaceName: "Workspace", channelName: "#general", webhookUrl: "#{url}"}) {
                result { id } errors { message }
              } }
              """,
              %{}
            )

          assert %{"data" => %{"connectPlace" => %{"result" => %{"id" => _}}}} = response

          conn =
            build_conn()
            |> authenticated_conn(context.current_user)
            |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
            |> dispatch(HuddlzWeb.Endpoint, :post, "/api/json/social_connections", %{
              "data" => %{
                "type" => "social_connection",
                "attributes" => %{
                  "group_id" => group.id,
                  "kind" => "slack",
                  "workspace_name" => "Workspace",
                  "channel_name" => "#general",
                  "webhook_url" => url
                }
              }
            })

          assert %{"data" => %{"id" => _}} = json_response(conn, 201)
        after
          Logger.delete_process_level(self())
        end
      end)

    Logger.configure(level: previous_level)
    Map.merge(context, %{diagnostic_log: log, diagnostic_secret: secret})
  end

  step "no webhook credential appears in the diagnostic logs", context do
    assert context.diagnostic_log != ""
    refute context.diagnostic_log =~ context.diagnostic_secret
    context
  end

  step "I try to send a test post after my address becomes unconfirmed", context do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, :platform_contacted)
      Req.Test.json(conn, %{})
    end)

    Ash.Seed.update!(context.current_user, %{confirmed_at: nil})

    result =
      Huddlz.Communities.send_social_test_post(context.connection.id, actor: context.current_user)

    Map.put(context, :post_result, result)
  end

  step "the test post is refused without contacting the platform", context do
    assert {:error, %Ash.Error.Forbidden{}} = context.post_result
    refute_receive :platform_contacted
    context
  end

  step "the Discord connection opens its channel in server {string}",
       %{args: [server]} = context do
    context.session
    |> assert_has("#social-connections", text: "Server #{server}")
    |> assert_has("a[href='https://discord.com/channels/#{server}/345626669224982402']",
      text: "Open channel"
    )

    context
  end

  step "I have chosen a week-before schedule and opening line for this connection", context do
    session =
      context
      |> open_connection("#general", "Elixir Nashville")
      |> check("A week before")
      |> fill_in("Opening line", with: "See you there!")
      |> click_button("Done")

    Map.merge(context, %{session: session, conn: session})
  end

  step "I reconnect this place through {word}", %{args: [platform]} = context do
    kind = platform |> String.downcase() |> String.to_existing_atom()
    group = context[:group] || lookup_group("Elixir Nashville")
    connection = context[:connection] || connection_of(group, kind)

    session = context |> open_connection(connection.channel_name, group.name)
    assert_has(session, "a", text: "Reconnect")

    Req.Test.stub(Huddlz.Social, fn conn -> Req.Test.json(conn, replacement_answer(kind)) end)

    session =
      follow_platform_handoff(
        session,
        group,
        kind,
        "/organize/#{group.slug}/social/reconnect/#{connection.id}"
      )

    Map.merge(context, %{session: session, conn: session, group: group, connection: connection})
  end

  step "{string} is paused", %{args: [_channel]} = context do
    connection =
      Huddlz.Communities.pause_social_connection!(context.connection, actor: context.current_user)

    Map.put(context, :connection, connection)
  end

  step "the same connection keeps its schedule, opening line and original attribution", context do
    [connection] =
      Huddlz.Communities.list_social_connections!(context.group.id, actor: context.current_user)

    assert connection.id == context.connection.id
    assert connection.moments == [:week_before]
    assert connection.opening_line == "See you there!"
    assert connection.connected_by_id == context.connection.connected_by_id
    assert connection.inserted_at == context.connection.inserted_at
    assert connection.state == :posting
    context
  end

  step "test posts use the replacement connection", context do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:post_path, conn.request_path})
      Req.Test.json(conn, %{})
    end)

    assert :ok =
             Huddlz.Communities.send_social_test_post(context.connection.id,
               actor: context.current_user
             )

    assert_receive {:post_path, "/services/T000/B000/replacement"}
    context
  end

  step "the platform no longer accepts a test post", context do
    Req.Test.stub(Huddlz.Social, fn conn -> Plug.Conn.resp(conn, 404, "revoked") end)

    session =
      context
      |> open_connection("#general", "Elixir Nashville")
      |> click_button("Send a test post")

    Map.merge(context, %{session: session, conn: session})
  end

  step "the connection shows as needing reconnection", context do
    assert_has(context.session, "#social-connections", text: "Needs reconnecting")
    assert_has(context.session, "#schedule-sheet a", text: "Reconnect")
    context
  end

  step "the morning-of preview starts with {string}", %{args: [line]} = context do
    context.session
    |> assert_has("#social-post-preview", text: line)
    |> assert_has("#social-post-preview", text: "Today at 6:00 PM")
    |> assert_has("#social-post-preview", text: "Online")
    |> assert_has("#social-post-preview", text: "12 spots left")
    |> assert_has("#social-post-preview", text: "/huddlz/example")

    context
  end

  step "I reconnect through the {word} API", %{args: [api]} = context do
    response = reconnect_api(api, context.current_user, context.connection.id)
    Map.merge(context, %{reconnect_response: response, reconnect_api: api})
  end

  step "the reconnection is {word}", %{args: [outcome]} = context do
    case {context.reconnect_api, outcome, context.reconnect_response} do
      {"GraphQL", "allowed",
       %{"data" => %{"reconnectSocialConnection" => %{"result" => %{"id" => id}, "errors" => []}}}} ->
        assert id == context.connection.id

      {"GraphQL", "refused", response} ->
        assert refused?(response["data"]["reconnectSocialConnection"], response["errors"])

      {"JSONAPI", "allowed", conn} ->
        assert %{"data" => %{"id" => id}} = json_response(conn, 200)
        assert id == context.connection.id

      {"JSONAPI", "refused", conn} ->
        assert %{"errors" => [_ | _]} = json_response(conn, 403)
    end

    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:post_path, conn.request_path})
      Req.Test.json(conn, %{})
    end)

    assert :ok =
             Huddlz.Communities.send_social_test_post(context.connection.id,
               actor: context.group.owner
             )

    expected =
      if outcome == "allowed",
        do: "/services/T000/B000/replacement",
        else: "/services/T000/B000/test"

    assert_receive {:post_path, ^expected}
    context
  end

  step "I reconnect without replacement credentials", context do
    result =
      Huddlz.Communities.reconnect_social_connection(context.connection, %{},
        actor: context.current_user
      )

    Map.put(context, :reconnect_result, result)
  end

  step "the incomplete reconnection is refused", context do
    assert {:error, %Ash.Error.Invalid{}} = context.reconnect_result
    context
  end

  defp reconnect_api("GraphQL", user, id) do
    gql(
      user,
      """
      mutation($id: ID!, $input: ReconnectSocialConnectionInput!) {
        reconnectSocialConnection(id: $id, input: $input) { result { id } errors { message code } }
      }
      """,
      %{
        "id" => id,
        "input" => %{"webhookUrl" => "https://hooks.slack.com/services/T000/B000/replacement"}
      }
    )
  end

  defp reconnect_api("JSONAPI", user, id) do
    build_conn()
    |> authenticated_conn(user)
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
    |> dispatch(HuddlzWeb.Endpoint, :patch, "/api/json/social_connections/#{id}/reconnect", %{
      "data" => %{
        "type" => "social_connection",
        "id" => id,
        "attributes" => %{
          "webhook_url" => "https://hooks.slack.com/services/T000/B000/replacement"
        }
      }
    })
  end

  step "I enter an opening line longer than 140 characters and finish", context do
    session =
      context
      |> open_connection("#general", "Elixir Nashville")
      |> fill_in("Opening line", with: String.duplicate("a", 141))
      |> click_button("Done")

    Map.merge(context, %{session: session, conn: session})
  end

  step "I can correct the opening line and the saved connection is unchanged", context do
    assert_has(context.session, "#schedule-sheet [role='alert']", text: "140")

    assert Huddlz.Communities.get_social_connection!(context.connection.id,
             actor: context.current_user
           ).opening_line == nil

    context
  end

  defp gql(user, query, variables) do
    build_conn()
    |> authenticated_conn(user)
    |> gql_post(query, variables)
    |> json_response(200)
  end

  # A mutation is refused when the API understood it and answered with a
  # policy or validation error rather than a result. A malformed query
  # (top-level errors) is not a refusal.
  defp refused?(%{"result" => nil, "errors" => [_ | _]}, nil), do: true
  defp refused?(_payload, _errors), do: false

  # The Social tab with the named connection's sheet open.
  defp open_connection(context, channel, group_name) do
    group = lookup_group(group_name)

    context.session
    |> visit("/organize/#{group.slug}/social")
    |> within("#social-connections", fn list -> click_button(list, "Edit") end)
    |> assert_has("#schedule-sheet", text: channel)
  end

  step "{string} posts to the Slack channel {string}", %{args: [group_name, channel]} = context do
    group = lookup_group(group_name) |> Ash.load!(:owner, authorize?: false)

    connection =
      generate(social_connection(group_id: group.id, channel_name: channel, actor: group.owner))

    Map.merge(context, %{connection: connection, group: group})
  end

  # What each platform answers when the code is exchanged.
  defp platform_answer(:slack, workspace, channel) do
    %{
      "ok" => true,
      "team" => %{"name" => workspace},
      "incoming_webhook" => %{
        "channel" => channel,
        "url" => "https://hooks.slack.com/services/T000/B000/secret"
      }
    }
  end

  defp platform_answer(:discord, _workspace, _channel) do
    %{
      "webhook" => %{
        "guild_id" => "290926792226357250",
        "channel_id" => "345626669224982402",
        "name" => "huddlz",
        "url" => "https://discord.com/api/webhooks/1/secret"
      }
    }
  end

  # What the platform answers when a place is reconnected: the same place
  # with a fresh webhook.
  defp replacement_answer(:slack) do
    platform_answer(:slack, "Elixir Nashville HQ", "#general")
    |> put_in(
      ["incoming_webhook", "url"],
      "https://hooks.slack.com/services/T000/B000/replacement"
    )
  end

  defp replacement_answer(:discord) do
    platform_answer(:discord, nil, nil)
    |> put_in(["webhook", "url"], "https://discord.com/api/webhooks/1/replacement")
  end

  defp connection_of(group, kind) do
    SocialConnection
    |> Ash.Query.filter(group_id == ^group.id and kind == ^kind)
    |> Ash.read_one!(authorize?: false)
  end

  defp follow_platform_handoff(session, group, kind, path \\ nil) do
    conn =
      dispatch(
        session.conn,
        HuddlzWeb.Endpoint,
        :get,
        path || "/organize/#{group.slug}/social/connect/#{kind}"
      )

    handoff = URI.parse(redirected_to(conn))
    assert handoff.host =~ Atom.to_string(kind)
    %{"state" => state} = URI.decode_query(handoff.query)

    callback =
      dispatch(
        session.conn,
        HuddlzWeb.Endpoint,
        :get,
        "/social/#{kind}/callback?code=platform-code&state=#{state}"
      )

    visit(session, redirected_to(callback))
  end

  defp lookup_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end
