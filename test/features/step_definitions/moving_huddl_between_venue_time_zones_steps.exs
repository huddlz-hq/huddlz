defmodule MovingHuddlBetweenVenueTimeZonesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Huddlz.Test.Helpers.LocationSelection
  import PhoenixTest

  alias Huddlz.Communities

  step "a physical huddl is scheduled for 9:00 AM in Miami", %{conn: conn} = context do
    owner = generate(user(role: :user))
    attendee = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))

    miami =
      Communities.create_group_location!(
        "Miami Coffee",
        "100 Biscayne Blvd, Miami, FL",
        29.89,
        -81.31,
        group.id,
        actor: owner
      )

    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 39.74, -104.99 ->
      {:ok, "America/Denver"}
    end)

    denver =
      Communities.create_group_location!(
        "Denver Coffee",
        "1701 Wynkoop St, Denver, CO",
        39.74,
        -104.99,
        group.id,
        actor: owner
      )

    huddl =
      Communities.create_huddl!(
        %{
          title: "Venue-local Coffee",
          group_id: group.id,
          group_location_id: miami.id,
          physical_location: miami.address,
          event_type: :in_person,
          date: Date.add(Date.utc_today(), 10),
          start_time: ~T[09:00:00],
          duration_minutes: 90,
          time_zone: miami.time_zone
        },
        actor: owner
      )

    Communities.rsvp_huddl!(huddl, %{}, actor: attendee)
    Oban.drain_queue(queue: :notifications)
    flush_mailbox()

    session = conn |> login(owner) |> visit("/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

    Map.merge(context, %{
      current_user: owner,
      attendee: attendee,
      denver: denver,
      huddl: huddl,
      original_starts_at: huddl.starts_at,
      original_ends_at: huddl.ends_at,
      session: session
    })
  end

  step "I move it to a venue in Denver", context do
    session =
      context.session
      |> select_saved_location(context.denver)
      |> click_button("Save changes")

    huddl = Communities.get_huddl!(context.huddl.id, actor: context.current_user)
    Map.merge(context, %{huddl: huddl, session: session})
  end

  step "it remains scheduled for 9:00 AM at the huddl", context do
    local_start = DateTime.shift_zone!(context.huddl.starts_at, context.huddl.time_zone)
    local_end = DateTime.shift_zone!(context.huddl.ends_at, context.huddl.time_zone)

    assert {local_start.hour, local_start.minute} == {9, 0}
    assert {local_end.hour, local_end.minute} == {10, 30}
    context
  end

  step "its Huddl time zone becomes {string}", %{args: [time_zone]} = context do
    assert context.huddl.time_zone == time_zone
    context
  end

  step "its stored UTC instant is recomputed", context do
    refute DateTime.compare(context.huddl.starts_at, context.original_starts_at) == :eq
    refute DateTime.compare(context.huddl.ends_at, context.original_ends_at) == :eq
    context
  end

  step "attendees receive the normal schedule-change notification", context do
    assert %{success: 1} = Oban.drain_queue(queue: :notifications)

    receive do
      {:email,
       %Swoosh.Email{
         subject: "Updated: Venue-local Coffee",
         to: [{"", attendee_email}],
         html_body: body
       }} ->
        assert attendee_email == to_string(context.attendee.email)
        assert body =~ "the start time"
        assert body =~ "the end time"
    after
      100 -> flunk("No schedule-change email received by the attendee")
    end

    context
  end

  defp flush_mailbox do
    receive do
      _message -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
