defmodule Huddlz.Communities.VenueMoveTimeZoneTest do
  use Huddlz.DataCase, async: false
  use Oban.Testing, repo: Huddlz.Repo

  @moduletag :issue405

  alias Huddlz.Communities
  alias Huddlz.Notifications

  test "moving a hybrid huddl preserves both venue-local wall-clock values" do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))
    miami = venue!(owner, group, "Miami", 29.89, -81.31)

    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 39.74, -104.99 ->
      {:ok, "America/Denver"}
    end)

    denver = venue!(owner, group, "Denver", 39.74, -104.99)
    date = Date.add(Date.utc_today(), 10)

    huddl =
      Communities.create_huddl!(
        %{
          title: "Hybrid Coffee",
          group_id: group.id,
          group_location_id: miami.id,
          physical_location: miami.address,
          virtual_link: "https://meet.example.com/coffee",
          event_type: :hybrid,
          date: date,
          start_time: ~T[09:00:00],
          duration_minutes: 90
        },
        actor: owner
      )

    moved =
      Communities.update_huddl!(
        huddl,
        %{
          group_location_id: denver.id,
          physical_location: denver.address,
          date: date,
          start_time: ~T[09:00:00],
          duration_minutes: 90
        },
        actor: owner
      )

    assert moved.time_zone == "America/Denver"
    assert moved.starts_at == local_utc!(date, ~T[09:00:00], "America/Denver")
    assert moved.ends_at == local_utc!(date, ~T[10:30:00], "America/Denver")
  end

  test "moving only the venue preserves the existing local schedule" do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))
    miami = venue!(owner, group, "Miami", 29.89, -81.31)

    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 39.74, -104.99 ->
      {:ok, "America/Denver"}
    end)

    denver = venue!(owner, group, "Denver", 39.74, -104.99)
    date = Date.add(Date.utc_today(), 10)

    huddl =
      Communities.create_huddl!(
        %{
          title: "Venue-only Coffee",
          group_id: group.id,
          group_location_id: miami.id,
          physical_location: miami.address,
          event_type: :in_person,
          date: date,
          start_time: ~T[09:00:00],
          duration_minutes: 90
        },
        actor: owner
      )

    moved =
      Communities.update_huddl!(
        huddl,
        %{group_location_id: denver.id, physical_location: denver.address},
        actor: owner
      )

    assert moved.time_zone == "America/Denver"
    assert moved.starts_at == local_utc!(date, ~T[09:00:00], "America/Denver")
    assert moved.ends_at == local_utc!(date, ~T[10:30:00], "America/Denver")
  end

  test "moving within one zone does not describe the schedule as changed" do
    owner = generate(user(role: :user))
    attendee = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))
    miami = venue!(owner, group, "Miami", 29.89, -81.31)
    new_york = venue!(owner, group, "New York", 40.71, -74.01)
    date = Date.add(Date.utc_today(), 10)

    huddl =
      Communities.create_huddl!(
        %{
          title: "Eastern Coffee",
          group_id: group.id,
          group_location_id: miami.id,
          physical_location: miami.address,
          event_type: :in_person,
          date: date,
          start_time: ~T[09:00:00],
          duration_minutes: 60
        },
        actor: owner
      )

    Communities.rsvp_huddl!(huddl, %{}, actor: attendee)
    Oban.drain_queue(queue: :notifications)

    moved =
      Communities.update_huddl!(
        huddl,
        %{
          group_location_id: new_york.id,
          physical_location: new_york.address,
          date: date,
          start_time: ~T[09:00:00],
          duration_minutes: 60
        },
        actor: owner
      )

    assert moved.starts_at == huddl.starts_at
    assert moved.ends_at == huddl.ends_at

    {:ok, %{results: notifications}} =
      Notifications.list_for_user(actor: attendee, page: [limit: 10])

    update = Enum.find(notifications, &(&1.trigger == "huddl_updated"))
    assert update.payload["changed_fields"] == ["physical_location"]
    assert update.description == "Changed: the location."
  end

  defp venue!(owner, group, city, latitude, longitude) do
    Communities.create_group_location!(
      "#{city} Coffee",
      "#{city} address",
      latitude,
      longitude,
      group.id,
      actor: owner
    )
  end

  defp local_utc!(date, time, time_zone) do
    date
    |> DateTime.new!(time, time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end
end
