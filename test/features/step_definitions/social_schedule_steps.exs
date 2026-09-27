defmodule SocialScheduleSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.SocialPost
  alias Huddlz.Social.Schedule

  # Every post a platform receives comes back to the test as a message.
  defp listen_to_platforms do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:social_post, conn.body_params["text"] || conn.body_params["content"]})
      Req.Test.json(conn, %{"ok" => true})
    end)
  end

  step "{string} posts to the Slack channel {string} a week before and the morning of",
       %{args: [group_name, channel]} = context do
    connect(context, group_name, channel, moments: [:week_before, :morning_of])
  end

  step "{string} posts to the Slack channel {string} the morning of",
       %{args: [group_name, channel]} = context do
    connect(context, group_name, channel, moments: [:morning_of])
  end

  step "{string} posts to the Slack channel {string} the morning of, opening with {string}",
       %{args: [group_name, channel, line]} = context do
    connect(context, group_name, channel, moments: [:morning_of], opening_line: line)
  end

  step "{string} posts to the Slack channel {string} when a huddl is published",
       %{args: [group_name, channel]} = context do
    connect(context, group_name, channel, moments: [:when_published])
  end

  step "{string} posts to the Slack channel {string} when a huddl is published and the morning of",
       %{args: [group_name, channel]} = context do
    connect(context, group_name, channel, moments: [:when_published, :morning_of])
  end

  step "I publish a public huddl {string} next week", %{args: [title]} = context do
    publish(context, title, is_private: false)
  end

  step "I publish a public huddl {string} three days from now", %{args: [title]} = context do
    publish(context, title, is_private: false, date: Date.add(eastern_today(), 3))
  end

  step "I publish a private huddl {string} next week", %{args: [title]} = context do
    publish(context, title, is_private: true)
  end

  step "I publish {string} every Thursday at 6:00 PM for twelve weeks",
       %{args: [title]} = context do
    publish_series(context, title, 12)
  end

  step "I publish {string} every Thursday at 6:00 PM for four weeks",
       %{args: [title]} = context do
    publish_series(context, title, 4)
  end

  step "{string} receives one post saying {string} and linking to the first {string}",
       %{args: [_channel, pattern, title]} = context do
    run_scheduler()
    text = next_post!()
    assert text =~ title
    assert text =~ pattern
    assert text =~ Huddlz.Social.huddl_link(nth_huddl(title, 1))
    refute_other_posts()
    context
  end

  step "the morning of the second {string} arrives", %{args: [title]} = context do
    title |> nth_huddl(2) |> arrive(:morning_of)
    context
  end

  step "{string} receives a post saying the second {string} is today at 6:00 PM",
       %{args: [_channel, title]} = context do
    text = next_post!()
    assert text =~ "Today at 6:00 PM"
    assert text =~ Huddlz.Social.huddl_link(nth_huddl(title, 2))
    refute_other_posts()
    context
  end

  step "the week-before post of {string} went out to {string}",
       %{args: [title, _channel]} = context do
    moment_arrives(title, :week_before)
    assert next_post!() =~ title
    context
  end

  step "I cancel {string}", %{args: [title]} = context do
    title
    |> lookup_huddl()
    |> Huddlz.Communities.cancel_huddl!(nil, actor: context.current_user)

    context
  end

  step "I move {string} to the next day", %{args: [title]} = context do
    huddl = lookup_huddl(title)

    Huddlz.Communities.update_huddl!(
      huddl,
      %{
        starts_at: DateTime.add(huddl.starts_at, 1, :day),
        ends_at: DateTime.add(huddl.ends_at, 1, :day)
      },
      actor: context.current_user
    )

    Map.put(context, :moved_from, huddl)
  end

  step "{string} receives a post saying {string} is cancelled",
       %{args: [_channel, title]} = context do
    run_scheduler()
    text = next_post!()
    assert text =~ "Cancelled: #{title}"
    refute_other_posts()
    context
  end

  step "{string} receives a post giving the new time of {string} and the old one",
       %{args: [_channel, title]} = context do
    run_scheduler()
    huddl = lookup_huddl(title)
    text = next_post!()
    assert text =~ "New time: #{title}"
    assert text =~ local_start(huddl)
    assert text =~ local_start(context.moved_from)
    refute_other_posts()
    context
  end

  step "Slack refuses the morning-of post of {string} because the connection was revoked",
       %{args: [title]} = context do
    Req.Test.stub(Huddlz.Social, fn conn -> Plug.Conn.resp(conn, 404, "no_service") end)
    moment_arrives(title, :morning_of)
    context
  end

  step "Slack fails once and then accepts the morning-of post of {string}",
       %{args: [title]} = context do
    test = self()
    attempts = :counters.new(1, [])

    Req.Test.stub(Huddlz.Social, fn conn ->
      :counters.add(attempts, 1, 1)

      if :counters.get(attempts, 1) == 1 do
        Plug.Conn.resp(conn, 500, "server_error")
      else
        send(test, {:social_post, conn.body_params["text"]})
        Req.Test.json(conn, %{"ok" => true})
      end
    end)

    moment_arrives(title, :morning_of)
    context
  end

  step "the Social tab of {string} shows {string} as needing reconnecting",
       %{args: [group_name, channel]} = context do
    session =
      context.session
      |> visit("/organize/#{lookup_group(group_name).slug}/social")
      |> assert_has("#social-connections [id^='social-connection-']", text: channel)
      |> assert_has("#social-connections [id^='social-connection-']", text: "Needs reconnecting")

    Map.put(context, :session, session)
  end

  step "Slack keeps failing the morning-of post of {string}", %{args: [title]} = context do
    Req.Test.stub(Huddlz.Social, fn conn -> Plug.Conn.resp(conn, 500, "server_error") end)
    moment_arrives(title, :morning_of)
    context
  end

  step "the Social tab of {string} shows {string} as posting",
       %{args: [group_name, channel]} = context do
    session =
      context.session
      |> visit("/organize/#{lookup_group(group_name).slug}/social")
      |> assert_has("#social-connections [id^='social-connection-']", text: channel)
      |> assert_has("#social-connections [id^='social-connection-']", text: "Posting")

    Map.put(context, :session, session)
  end

  step "it lists the morning-of post of {string} as not sent", %{args: [title]} = context do
    context.session
    |> assert_has("#recent-social-posts [id^='social-post-']", text: title)
    |> assert_has("#recent-social-posts [id^='social-post-']", text: "Morning of")
    |> assert_has("#recent-social-posts [id^='social-post-']", text: "Didn't send")

    context
  end

  step "{string} is emailed that posts to {string} stopped while posting {string}",
       %{args: [email, channel, title]} = context do
    [sent] = emails_about(channel)
    assert [{_, ^email}] = sent.to
    assert sent.text_body =~ title
    assert sent.html_body =~ "/organize/#{context.group.slug}/social"
    context
  end

  step "nobody is emailed about {string}", %{args: [channel]} = context do
    assert emails_about(channel) == []
    context
  end

  step "{string} is resumed", %{args: [_channel]} = context do
    connection =
      Huddlz.Communities.resume_social_connection!(context.connection,
        actor: context.current_user
      )

    Map.put(context, :connection, connection)
  end

  step "{string} receives nothing", %{args: [_channel]} = context do
    run_scheduler()
    refute_received {:social_post, _}
    context
  end

  step "the Social tab of {string} lists the morning-of post of {string} as upcoming",
       %{args: [group_name, title]} = context do
    session =
      context.session
      |> visit("/organize/#{lookup_group(group_name).slug}/social")
      |> assert_has("#upcoming-social-posts [id^='social-post-']", text: title)
      |> assert_has("#upcoming-social-posts [id^='social-post-']", text: "Morning of")

    Map.put(context, :session, session)
  end

  step "it lists no week-before post of {string}", %{args: [_title]} = context do
    refute_has(context.session, "#upcoming-social-posts", text: "Week before")
    context
  end

  step "the upcoming posts on the Social tab of {string} do not mention {string}",
       %{args: [group_name, title]} = context do
    context.session
    |> visit("/organize/#{lookup_group(group_name).slug}/social")
    |> assert_has("#upcoming-social-posts")
    |> refute_has("#upcoming-social-posts", text: title)

    context
  end

  step "{string} receives a post about {string}", %{args: [_channel, title]} = context do
    run_scheduler()
    huddl = lookup_huddl(title)
    text = next_post!()
    assert text =~ title
    assert text =~ Huddlz.Social.huddl_link(huddl)
    refute_other_posts()
    context
  end

  step "every spot at {string} is taken and someone is on the waitlist",
       %{args: [title]} = context do
    huddl = lookup_huddl(title)

    # The owner who created it is already going; one more fills it.
    huddl =
      Huddlz.Communities.update_huddl!(huddl, %{max_attendees: 2}, actor: context.group.owner)

    [going, waiting] = generate_many(user(), 2)
    Huddlz.Communities.rsvp_huddl!(huddl, actor: going)
    Huddlz.Communities.join_waitlist_huddl!(huddl, actor: waiting)
    context
  end

  step "{string} has a public huddl {string} in ten days at 6:00 PM",
       %{args: [group_name, title]} = context do
    group = lookup_group(group_name)

    generate(
      huddl(
        group_id: group.id,
        title: title,
        date: Date.add(eastern_today(), 10),
        start_time: ~T[18:00:00],
        duration_minutes: 120,
        actor: group.owner
      )
    )

    context
  end

  step "the week-before moment of {string} arrives", %{args: [title]} = context do
    moment_arrives(title, :week_before)
    context
  end

  step "the morning of {string} arrives", %{args: [title]} = context do
    moment_arrives(title, :morning_of)
    context
  end

  step "{string} receives a post naming {string}, its time, its place and its link",
       %{args: [_channel, title]} = context do
    huddl = lookup_huddl(title)
    text = next_post!()
    local = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)

    assert text =~ title
    assert text =~ Calendar.strftime(local, "%a, %b %-d at 6:00 PM")
    assert text =~ huddl.physical_location
    assert text =~ Huddlz.Social.huddl_link(huddl)
    refute_other_posts()
    context
  end

  step "{string} receives a post saying {string} is today at 6:00 PM",
       %{args: [_channel, title]} = context do
    text = next_post!()
    assert text =~ title
    assert text =~ "Today at 6:00 PM"
    refute_other_posts()
    context
  end

  step "the post to {string} begins with {string}", %{args: [_channel, line]} = context do
    assert String.starts_with?(next_post!(), line <> "\n")
    context
  end

  step "{string} receives a post saying {string} is full and the waitlist is open",
       %{args: [_channel, title]} = context do
    text = next_post!()
    assert text =~ title
    assert text =~ "Full, waitlist open"
    context
  end

  # Publishes a huddl a week out as the signed-in organizer.
  defp publish(context, title, attrs) do
    group = context[:group] || lookup_group("Elixir Nashville")

    Huddlz.Communities.create_huddl!(
      Map.merge(
        %{
          group_id: group.id,
          title: title,
          date: Date.add(eastern_today(), 7),
          start_time: ~T[18:00:00],
          duration_minutes: 120,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/hack-night",
          lifecycle_state: :published
        },
        Map.new(attrs)
      ),
      actor: context.current_user
    )

    context
  end

  step "{string} asks the API for the upcoming social posts of {string}",
       %{args: [email, group_name]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

    response =
      build_conn()
      |> authenticated_conn(user)
      |> gql_post(
        """
        query($groupId: ID!) {
          upcomingSocialPosts(groupId: $groupId) {
            occasion dueAt
            huddl { title timeZone }
            socialConnection { channelName }
          }
        }
        """,
        %{"groupId" => lookup_group(group_name).id}
      )
      |> json_response(200)

    assert response["errors"] == nil, inspect(response)
    Map.put(context, :upcoming, response["data"]["upcomingSocialPosts"])
  end

  step "the answer lists the week-before and morning-of posts of {string} with their times",
       %{args: [title]} = context do
    huddl = lookup_huddl(title)

    expected =
      for moment <- [:week_before, :morning_of] do
        %{
          "occasion" => moment |> Atom.to_string() |> String.upcase(),
          "dueAt" => moment |> Schedule.due_at(huddl) |> DateTime.to_iso8601(),
          "huddl" => %{"title" => title, "timeZone" => huddl.time_zone},
          "socialConnection" => %{"channelName" => "#general"}
        }
      end

    assert context.upcoming == expected
    context
  end

  step "the answer lists no posts", context do
    assert context.upcoming == []
    context
  end

  defp connect(context, group_name, channel, opts) do
    listen_to_platforms()
    group = lookup_group(group_name)

    connection =
      generate(
        social_connection(
          group_id: group.id,
          channel_name: channel,
          moments: Keyword.fetch!(opts, :moments),
          opening_line: opts[:opening_line],
          actor: group.owner
        )
      )

    Map.merge(context, %{connection: connection, group: group})
  end

  # A weekly series from next Thursday, with its dates generated as the
  # background job would.
  defp publish_series(context, title, weeks) do
    today = eastern_today()
    # The next Thursday after today, one to seven days out.
    thursday = Date.add(today, rem(10 - Date.day_of_week(today), 7) + 1)

    publish(context, title,
      date: thursday,
      is_recurring: true,
      frequency: "weekly",
      repeat_until: Date.add(thursday, 7 * (weeks - 1))
    )

    Oban.drain_queue(queue: :default)
    context
  end

  # The nth huddl of that title, soonest first.
  defp nth_huddl(title, n) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.Query.load(:group)
    |> Ash.read!(authorize?: false)
    |> Enum.at(n - 1)
  end

  # The clock reaches the moment: the post planned for it becomes due, and
  # the scheduler runs as it would each minute.
  defp moment_arrives(title, moment), do: title |> lookup_huddl() |> arrive(moment)

  defp arrive(huddl, moment) do
    title = huddl.title
    expected = Schedule.due_at(moment, huddl)

    post =
      SocialPost
      |> Ash.Query.filter(huddl_id == ^huddl.id and occasion == ^moment and state == :scheduled)
      |> Ash.read_one!(authorize?: false)

    assert post, "no #{moment} post is planned for #{title}"
    assert DateTime.compare(post.due_at, expected) == :eq

    Ash.Seed.update!(post, %{due_at: DateTime.add(DateTime.utc_now(), -1, :second)})
    run_scheduler()
  end

  # Runs the scheduler and every job it queues, retries included.
  defp run_scheduler do
    AshOban.Test.schedule_and_run_triggers(SocialPost,
      drain_queues?: true,
      with_scheduled: true,
      with_recursion: true
    )
  end

  # Delivers queued email, then keeps what says posts to that channel stopped.
  defp emails_about(channel) do
    Oban.drain_queue(queue: :notifications)

    Stream.repeatedly(fn ->
      receive do
        {:email, sent} -> sent
      after
        0 -> nil
      end
    end)
    |> Enum.take_while(& &1)
    |> Enum.filter(&(&1.subject == "Posts to #{channel} have stopped"))
  end

  defp local_start(huddl) do
    huddl.starts_at
    |> DateTime.shift_zone!(huddl.time_zone)
    |> Calendar.strftime("%a, %b %-d at %-I:%M %p")
  end

  defp next_post! do
    assert_receive {:social_post, text}, 1_000
    text
  end

  defp refute_other_posts, do: refute_received({:social_post, _})

  defp lookup_group(name) do
    Group
    |> Ash.Query.filter(name == ^name)
    |> Ash.Query.load(:owner)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_huddl(title) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end
end
