defmodule Huddlz.Communities.VenueTimeZoneTest do
  use Huddlz.DataCase, async: true

  @moduletag :issue404

  alias Huddlz.Communities

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

    test "an unresolved venue requires a canonical manual time zone" do
      owner = generate(user(role: :user))
      group = generate(group(actor: owner))

      Mox.expect(Huddlz.MockLocationTimeZone, :resolve, 3, fn latitude, longitude ->
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

      assert Exception.message(missing_error) =~ "must be a valid IANA time zone"

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

      assert Exception.message(invalid_error) =~ "must be a valid IANA time zone"

      assert {:ok, location} =
               Communities.create_group_location(
                 "Unknown Venue",
                 "Unknown",
                 0.0,
                 0.0,
                 group.id,
                 %{time_zone: "America/New_York"},
                 actor: owner
               )

      assert location.time_zone == "America/New_York"
    end

    test "existing saved venues are backfilled and the column is required" do
      migration =
        File.read!(
          Path.expand(
            "../../../priv/repo/migrations/20260901152555_add_group_location_time_zone.exs",
            __DIR__
          )
        )

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

    test "missing and invalid huddl zones are rejected without a resolved venue" do
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

      assert {:error, missing_error} =
               Communities.create_huddl(Map.put(attrs, :time_zone, nil), actor: owner)

      assert Exception.message(missing_error) =~ "must be a valid IANA time zone"

      assert {:error, invalid_error} =
               Communities.create_huddl(Map.put(attrs, :time_zone, "EST"), actor: owner)

      assert Exception.message(invalid_error) =~ "must be a valid IANA time zone"
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
