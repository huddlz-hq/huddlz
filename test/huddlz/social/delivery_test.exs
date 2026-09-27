defmodule Huddlz.Social.DeliveryTest do
  # Stubs the platforms' webhooks through Req.Test, owned by this process.
  use Huddlz.DataCase, async: true

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.SocialPost

  setup do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:social_post, conn.body_params["text"]})
      Req.Test.json(conn, %{"ok" => true})
    end)

    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    connection =
      generate(social_connection(group_id: group.id, moments: [:morning_of], actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          date: Date.add(eastern_today(), 10),
          start_time: ~T[18:00:00],
          duration_minutes: 120,
          actor: owner
        )
      )

    %{owner: owner, connection: connection, huddl: huddl}
  end

  test "a post queued before its huddl moved later waits for the new time", %{
    owner: owner,
    huddl: huddl
  } do
    post = morning_of(huddl)
    Ash.Seed.update!(post, %{due_at: DateTime.add(DateTime.utc_now(), -1, :second)})

    # The scheduler queues the post's job, then the huddl moves a day later
    # before the job runs.
    AshOban.schedule(SocialPost, :deliver)
    Oban.drain_queue(queue: :social)

    Communities.update_huddl!(
      huddl,
      %{
        starts_at: DateTime.add(huddl.starts_at, 1, :day),
        ends_at: DateTime.add(huddl.ends_at, 1, :day)
      },
      actor: owner
    )

    Oban.drain_queue(queue: :social)

    refute_received {:social_post, _}
    post = morning_of(huddl)
    assert post.state == :scheduled
    assert DateTime.after?(post.due_at, DateTime.utc_now())
  end

  test "a huddl moved to another time zone gives its old time where it was", %{
    owner: owner,
    connection: connection,
    huddl: huddl
  } do
    Ash.Seed.seed!(SocialPost, %{
      social_connection_id: connection.id,
      huddl_id: huddl.id,
      occasion: :week_before,
      due_at: DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.truncate(:second),
      state: :sent
    })

    # The address book place is in Chicago; the huddl keeps its 6:00 PM
    # there, an hour later than it was in New York.
    chicago = generate(group_location(group_id: huddl.group_id, actor: owner))

    moved =
      Communities.update_huddl!(huddl, %{group_location_id: chicago.id}, actor: owner)

    assert moved.time_zone == "America/Chicago"
    AshOban.Test.schedule_and_run_triggers(SocialPost, drain_queues?: true)

    assert_received {:social_post, text}

    day =
      huddl.starts_at
      |> DateTime.shift_zone!("America/New_York")
      |> Calendar.strftime("%a, %b %-d")

    was = "#{day} at 6:00 PM EDT"
    now = "#{day} at 6:00 PM CDT"

    assert text =~ "is now #{now} (was #{was})."
  end

  defp morning_of(huddl) do
    SocialPost
    |> Ash.Query.filter(huddl_id == ^huddl.id and occasion == :morning_of)
    |> Ash.read_one!(authorize?: false)
  end
end
