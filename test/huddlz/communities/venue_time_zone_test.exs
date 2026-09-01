defmodule Huddlz.Communities.VenueTimeZoneTest do
  use Huddlz.DataCase, async: true

  @moduletag :issue404

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl

  describe "saved venue time zones" do
    test "coordinates resolve through the location time-zone boundary" do
      owner = generate(user(role: :user))
      group = generate(group(actor: owner))

      Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 39.74, -104.99 ->
        {:ok, "America/Denver"}
      end)

      location =
        Communities.create_group_location!(
          "Denver Coffee",
          "1701 Wynkoop St, Denver, CO",
          39.74,
          -104.99,
          group.id,
          actor: owner
        )

      assert location.time_zone == "America/Denver"
    end

    test "an unresolved venue cannot be saved with a manual time zone" do
      owner = generate(user(role: :user))
      group = generate(group(actor: owner))

      Mox.expect(Huddlz.MockLocationTimeZone, :resolve, 2, fn latitude, longitude ->
        assert latitude == 0.0
        assert longitude == 0.0
        {:error, :not_found}
      end)

      assert {:error, missing_error} =
               Communities.create_group_location(
                 "Unknown Venue",
                 "Unknown",
                 0.0,
                 0.0,
                 group.id,
                 actor: owner
               )

      assert Exception.message(missing_error) =~ "time zone could not be resolved"

      assert {:error, invalid_error} =
               Communities.create_group_location(
                 "Unknown Venue",
                 "Unknown",
                 0.0,
                 0.0,
                 group.id,
                 %{time_zone: "EST"},
                 actor: owner
               )

      assert Exception.message(invalid_error) =~ "time_zone"
    end

    test "existing saved venues are backfilled and the column is required" do
      [migration_path] =
        Path.wildcard(
          Path.expand("../../../priv/repo/migrations/*_calendar_time_zones.exs", __DIR__)
        )

      migration = File.read!(migration_path)

      assert migration =~ "SET time_zone = 'America/New_York'"

      assert %{rows: [["NO"]]} =
               Repo.query!("""
               SELECT is_nullable
               FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'group_locations'
                 AND column_name = 'time_zone'
               """)

      assert %{rows: [[0]]} =
               Repo.query!("SELECT COUNT(*) FROM group_locations WHERE time_zone IS NULL")
    end
  end

  describe "physical and hybrid huddl time zones" do
    test "the selected venue overrides an unrelated submitted zone" do
      owner = generate(user(role: :user))
      group = generate(group(actor: owner, time_zone: "America/New_York"))
      location = generate(group_location(group_id: group.id, actor: owner))

      for event_type <- [:in_person, :hybrid] do
        huddl =
          Communities.create_huddl!(
            %{
              title: "Denver #{event_type}",
              group_id: group.id,
              group_location_id: location.id,
              physical_location: location.address,
              virtual_link: event_type == :hybrid && "https://meet.example.com/denver",
              event_type: event_type,
              date: Date.add(Date.utc_today(), 10),
              start_time: ~T[09:00:00],
              duration_minutes: 60,
              time_zone: "America/Los_Angeles"
            },
            actor: owner
          )

        assert huddl.time_zone == location.time_zone
        assert DateTime.shift_zone!(huddl.starts_at, location.time_zone).hour == 9
        assert DateTime.shift_zone!(huddl.ends_at, location.time_zone).hour == 10
      end
    end

    test "physical and hybrid huddlz require a saved venue" do
      owner = generate(user(role: :user))
      group = generate(group(actor: owner))

      attrs = %{
        title: "Unresolved physical huddl",
        group_id: group.id,
        physical_location: "Unknown Venue",
        event_type: :in_person,
        date: Date.add(Date.utc_today(), 10),
        start_time: ~T[09:00:00],
        duration_minutes: 60
      }

      for event_type <- [:in_person, :hybrid] do
        attrs =
          attrs
          |> Map.put(:event_type, event_type)
          |> Map.put(:virtual_link, event_type == :hybrid && "https://meet.example.com/venue")

        assert {:error, error} = Communities.create_huddl(attrs, actor: owner)
        assert Exception.message(error) =~ "saved venue is required"
      end
    end

    test "legacy physical huddlz without saved venues still accept RSVPs" do
      owner = generate(user(role: :user))
      attendee = generate(user(role: :user))
      group = generate(group(actor: owner))
      now = DateTime.utc_now()

      legacy_huddl =
        Ash.Seed.seed!(Huddl, %{
          title: "Legacy physical huddl",
          starts_at: DateTime.add(now, 1, :day),
          ends_at: DateTime.add(now, 2, :day),
          time_zone: "America/New_York",
          event_type: :in_person,
          physical_location: "Legacy Venue",
          group_id: group.id,
          creator_id: owner.id,
          lifecycle_state: :published,
          published_at: now,
          published_by_id: owner.id
        })

      assert {:ok, _huddl} = Communities.rsvp_huddl(legacy_huddl, %{}, actor: attendee)
    end

    test "a saved venue must belong to the huddl's group" do
      owner = generate(user(role: :user))
      other_owner = generate(user(role: :user))
      group = generate(group(actor: owner))
      other_group = generate(group(actor: other_owner))
      other_location = generate(group_location(group_id: other_group.id, actor: other_owner))

      assert {:error, error} =
               Communities.create_huddl(
                 %{
                   title: "Wrong group venue",
                   group_id: group.id,
                   group_location_id: other_location.id,
                   physical_location: other_location.address,
                   event_type: :in_person,
                   date: Date.add(Date.utc_today(), 10),
                   start_time: ~T[09:00:00],
                   duration_minutes: 60,
                   time_zone: "America/New_York"
                 },
                 actor: owner
               )

      assert Exception.message(error) =~ "saved venue must belong to the huddl's group"
    end

    test "a selected venue that cannot be loaded rejects the huddl" do
      owner = generate(user(role: :user))
      group = generate(group(actor: owner))

      assert {:error, error} =
               Communities.create_huddl(
                 %{
                   title: "Unavailable venue",
                   group_id: group.id,
                   group_location_id: Ash.UUID.generate(),
                   physical_location: "Unavailable Venue",
                   event_type: :in_person,
                   date: Date.add(Date.utc_today(), 10),
                   start_time: ~T[09:00:00],
                   duration_minutes: 60,
                   time_zone: "America/New_York"
                 },
                 actor: owner
               )

      assert Exception.message(error) =~ "selected venue is not available"
    end
  end
end
