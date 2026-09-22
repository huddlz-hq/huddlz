defmodule SocialConnectionsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 4, json_response: 2, redirected_to: 1]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

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
    assert_has(context.session, "#social-connections .row", text: channel)
    assert_has(context.session, "#social-connections .row", text: platform)
    context
  end

  step "the connection shows as posting", context do
    assert_has(context.session, "#social-connections .row", text: "Posting")
    context
  end

  step "the activity of {string} says {string}", %{args: [group_name, line]} = context do
    group = lookup_group(group_name)

    context.session
    |> visit("/organize/#{group.slug}")
    |> assert_has("#recent-activity .line", text: line)

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
    |> assert_has("#social-connections .row", text: channel)
    |> assert_has("#social-connections .row", text: line)

    context
  end

  step "I pause {string} from the Social tab of {string}",
       %{args: [channel, group_name]} = context do
    group = lookup_group(group_name)

    session =
      context.session
      |> visit("/organize/#{group.slug}/social")
      |> within("#social-connections", fn row -> click_button(row, "Pause") end)

    Map.merge(context, %{session: session, conn: session, group: group})
  end

  step "the connection shows as paused", context do
    assert_has(context.session, "#social-connections .row", text: "Paused")
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
    |> assert_has("#social-connections .row", text: channel)
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
    |> refute_has("#social-connections .row")

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
    |> assert_has("#social-connections .row", text: "connected by #{name}")

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

  defp platform_answer(:discord, workspace, channel) do
    %{
      "guild" => %{"name" => workspace},
      "webhook" => %{
        "name" => String.trim_leading(channel, "#"),
        "url" => "https://discord.com/api/webhooks/1/secret"
      }
    }
  end

  defp follow_platform_handoff(session, group, kind) do
    conn =
      dispatch(
        session.conn,
        HuddlzWeb.Endpoint,
        :get,
        "/organize/#{group.slug}/social/connect/#{kind}"
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
