defmodule SocialScheduleSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  require Ash.Query

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

  step "I publish a public huddl {string} next week", %{args: [title]} = context do
    publish(context, title, is_private: false)
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

  # The clock reaches the moment: the post planned for it becomes due, and
  # the scheduler runs as it would each minute.
  defp moment_arrives(title, moment) do
    huddl = lookup_huddl(title)
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

  defp run_scheduler do
    AshOban.Test.schedule_and_run_triggers(SocialPost, drain_queues?: true, with_scheduled: true)
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
