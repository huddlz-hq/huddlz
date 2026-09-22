defmodule SocialConnectionsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.ConnTest, only: [dispatch: 4, redirected_to: 1]
  import PhoenixTest

  require Ash.Query

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
