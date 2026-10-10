defmodule SocialSteeringSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, Huddl, SocialConnection}

  step "{string} also posts to the Discord channel {string} the morning of",
       %{args: [group_name, channel]} = context do
    group = lookup_group(group_name)

    generate(
      social_connection(
        group_id: group.id,
        kind: :discord,
        workspace_name: "Music City Makers",
        channel_name: channel,
        webhook_url: "https://discord.com/api/webhooks/1/secret",
        moments: [:morning_of],
        actor: group.owner
      )
    )

    # Posts come back tagged with the platform they went to, so the test
    # can tell the two channels apart.
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      text = conn.body_params["text"] || conn.body_params["content"]
      send(test, {:social_post, text})
      send(test, {:social_post_on, platform(conn.host)})
      Req.Test.json(conn, %{"ok" => true})
    end)

    context
  end

  step "{string} has a public huddl {string} in three days at 6:00 PM",
       %{args: [group_name, title]} = context do
    create_huddl(group_name, title, days: 3)
    context
  end

  step "{string} has a private huddl {string} in ten days at 6:00 PM",
       %{args: [group_name, title]} = context do
    create_huddl(group_name, title, days: 10, is_private: true)
    context
  end

  step "{string} is skipped on {string}", %{args: [title, channel]} = context do
    huddl = lookup_huddl(title)

    Huddlz.Communities.skip_social_connection!(huddl, connection(channel).id,
      actor: huddl.group.owner
    )

    context
  end

  step "I open {string} in the organize workspace", %{args: [title]} = context do
    huddl = lookup_huddl(title)

    session =
      context.session
      |> visit("/organize/#{huddl.group.slug}/huddlz")
      |> click_link("#organize-huddl-link-#{huddl.id}", title)
      |> assert_has("h1", text: title)

    Map.merge(context, %{session: session, huddl: huddl})
  end

  step "the Social posts panel lists the week-before and morning-of posts to {string} with their times",
       %{args: [channel]} = context do
    # The huddl is ten days out at 6:00 PM Eastern: a week before is three
    # days out at 6:00 PM, and the morning of is 9:00 AM on the day.
    day = Date.add(eastern_today(), 10)

    context.session
    |> assert_post(channel, "Week before", Date.add(day, -7), "6:00 PM")
    |> assert_post(channel, "Morning of", day, "9:00 AM")

    context
  end

  step "I turn off posting it to {string}", %{args: [channel]} = context do
    session = uncheck(context.session, "Post this huddl to #{channel}")
    Map.put(context, :session, session)
  end

  step "I turn posting it to {string} back on", %{args: [channel]} = context do
    session = check(context.session, "Post this huddl to #{channel}")
    Map.put(context, :session, session)
  end

  step "the Social posts panel shows {string} as skipped for this huddl",
       %{args: [channel]} = context do
    assert_has(context.session, block(channel), text: "Skipped for this huddl")

    context
  end

  step "the Social posts panel lists the morning-of post to {string}",
       %{args: [channel]} = context do
    assert_has(context.session, "#{block(channel)} [id^='huddl-social-post-']",
      text: "Morning of"
    )

    context
  end

  step "it lists no week-before post", context do
    refute_has(context.session, "#social-posts", text: "Week before")
    context
  end

  step "the activity of {string} shows {string} skipped {string} on {string}",
       %{args: [group_name, name, title, channel]} = context do
    assert_activity(context, group_name, "#{name} skipped #{title} on Slack · #{channel}")
  end

  step "the activity of {string} shows {string} posted {string} to {string}",
       %{args: [group_name, name, title, channel]} = context do
    assert_activity(context, group_name, "#{name} posted #{title} to Slack · #{channel}")
  end

  step "only {string} receives a post", %{args: [channel]} = context do
    assert_receive {:social_post_on, platform}, 1_000
    assert platform == connection(channel).kind
    refute_received {:social_post_on, _}
    context
  end

  step "I post it now to {string}", %{args: [channel]} = context do
    session = click_button(context.session, "#{block(channel)} button", "Post now")
    Map.put(context, :session, session)
  end

  step "Slack is temporarily unavailable", context do
    Req.Test.stub(Huddlz.Social, fn conn -> Plug.Conn.resp(conn, 503, "try later") end)
    context
  end

  step "I am told huddlz will try posting again", context do
    assert_has(context.session, "[role='alert']", text: "huddlz will try again in a minute")
    context
  end

  step "the Social posts panel lists a post to {string} as awaiting delivery",
       %{args: [channel]} = context do
    context.session
    |> assert_has(block(channel), text: "Posted now")
    |> refute_has(block(channel), text: "Sent")

    context
  end

  step "Slack accepts posts again", context do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:social_post, conn.body_params["text"]})
      Req.Test.json(conn, %{"ok" => true})
    end)

    context
  end

  step "huddlz retries its social posts", context do
    AshOban.Test.schedule_and_run_triggers(Huddlz.Communities.SocialPost,
      drain_queues?: true,
      with_scheduled: true,
      with_recursion: true
    )

    context
  end

  step "the Social posts panel lists a post to {string} as posted now and sent",
       %{args: [channel]} = context do
    assert_has(context.session, "#{block(channel)} [id^='huddl-social-post-']",
      text: "Posted now"
    )

    assert_has(context.session, "#{block(channel)} [id^='huddl-social-post-']", text: "Sent")
    context
  end

  step "the Social posts panel shows {string} as paused", %{args: [channel]} = context do
    assert_has(context.session, block(channel), text: "Paused")
    context
  end

  step "Slack refuses posts because the connection was revoked", context do
    Req.Test.stub(Huddlz.Social, fn conn -> Plug.Conn.resp(conn, 404, "no_service") end)
    context
  end

  step "the Social posts panel shows {string} as needing reconnecting",
       %{args: [channel]} = context do
    assert_has(context.session, block(channel), text: "Needs reconnecting")
    context
  end

  step "the Social posts panel lists a post to {string} as not sent",
       %{args: [channel]} = context do
    assert_has(context.session, block(channel), text: "Didn't send")
    context
  end

  step "the Social posts panel offers only to copy the post", context do
    context.session
    |> assert_has("#social-posts button", text: "Copy post")
    |> refute_has("#social-posts [role='switch']")
    |> refute_has("#social-posts button", text: "Post now")

    context
  end

  step "there is no Social posts panel", context do
    refute_has(context.session, "#social-posts")
    context
  end

  step "{string} asks the API to skip {string} on {string}",
       %{args: [email, title, channel]} = context do
    steer(context, email, "skipHuddlOnSocialConnection", title, channel)
  end

  step "{string} asks the API to unskip {string} on {string}",
       %{args: [email, title, channel]} = context do
    steer(context, email, "unskipHuddlOnSocialConnection", title, channel)
  end

  step "{string} asks the API to post {string} now to {string}",
       %{args: [email, title, channel]} = context do
    steer(context, email, "postHuddlNow", title, channel)
  end

  step "the API refuses", context do
    assert [%{"message" => _} | _] = context.api_errors
    context
  end

  step "the API lists {string} as skipped on {string} with no posts planned",
       %{args: [title, channel]} = context do
    answer = huddl_social_posts(context, title)
    assert answer["skips"] == [%{"socialConnection" => %{"channelName" => channel}}]
    assert answer["posts"] == []
    context
  end

  step "the API lists the morning-of post of {string} on {string}",
       %{args: [title, channel]} = context do
    answer = huddl_social_posts(context, title)
    assert answer["skips"] == []

    assert answer["posts"] == [
             %{
               "occasion" => "MORNING_OF",
               "state" => "scheduled",
               "socialConnection" => %{"channelName" => channel}
             }
           ]

    context
  end

  defp steer(context, email, mutation, title, channel) do
    user = lookup_user(email)
    huddl = lookup_huddl(title)

    response =
      build_conn()
      |> authenticated_conn(user)
      |> gql_post(
        """
        mutation($id: ID!, $input: #{input_type(mutation)}!) {
          #{mutation}(id: $id, input: $input) {
            result { id }
            errors { message }
          }
        }
        """,
        %{"id" => huddl.id, "input" => %{"socialConnectionId" => connection(channel).id}}
      )
      |> json_response(200)

    errors =
      (response["errors"] || []) ++ (get_in(response, ["data", mutation, "errors"]) || [])

    Map.merge(context, %{api_errors: errors, api_user: user})
  end

  # GraphQL names each mutation's input after the mutation.
  defp input_type(<<first::binary-size(1), rest::binary>>),
    do: String.upcase(first) <> rest <> "Input"

  defp huddl_social_posts(context, title) do
    response =
      build_conn()
      |> authenticated_conn(context.api_user)
      |> gql_post(
        """
        query($huddlId: ID!) {
          posts: huddlSocialPosts(huddlId: $huddlId) {
            occasion state
            socialConnection { channelName }
          }
          skips: huddlSocialSkips(huddlId: $huddlId) {
            socialConnection { channelName }
          }
        }
        """,
        %{"huddlId" => lookup_huddl(title).id}
      )
      |> json_response(200)

    assert response["errors"] == nil, inspect(response)
    response["data"]
  end

  defp assert_post(session, channel, moment, date, time) do
    assert_has(session, "#{block(channel)} [id^='huddl-social-post-']", text: moment)

    assert_has(session, "#{block(channel)} [id^='huddl-social-post-']",
      text: Calendar.strftime(date, "%a %-d %b, ") <> time
    )
  end

  defp assert_activity(context, group_name, line) do
    context.session
    |> visit("/organize/#{lookup_group(group_name).slug}")
    |> assert_has("#recent-activity", text: line)

    context
  end

  # The panel's block for one connection.
  defp block(channel), do: "#social-posts-connection-#{connection(channel).id}"

  defp platform("discord.com"), do: :discord
  defp platform("hooks.slack.com"), do: :slack

  defp create_huddl(group_name, title, opts) do
    group = lookup_group(group_name)

    generate(
      huddl(
        group_id: group.id,
        title: title,
        date: Date.add(eastern_today(), Keyword.fetch!(opts, :days)),
        start_time: ~T[18:00:00],
        duration_minutes: 120,
        is_private: Keyword.get(opts, :is_private, false),
        actor: group.owner
      )
    )
  end

  defp connection(channel) do
    SocialConnection
    |> Ash.Query.filter(channel_name == ^channel)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp lookup_group(name) do
    Group
    |> Ash.Query.filter(name == ^name)
    |> Ash.Query.load(:owner)
    |> Ash.read_one!(authorize?: false)
  end

  # Read as the group's owner: huddlz reads hide private huddlz from
  # everyone else.
  defp lookup_huddl(title) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.Query.load(group: [:owner])
    |> Ash.read_one!(actor: lookup_user("owner@example.com"), authorize?: false)
  end
end
