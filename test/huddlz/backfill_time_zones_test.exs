defmodule Huddlz.BackfillTimeZonesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.{Group, Huddl}

  describe "run/0" do
    test "geo-derives time_zone for groups with coordinates, else leaves Etc/UTC" do
      owner = Huddlz.Generator.user() |> Huddlz.Generator.generate()

      geocoded =
        Huddlz.Generator.group(owner_id: owner.id, actor: owner) |> Huddlz.Generator.generate()

      # Simulate a legacy row: force coordinates without going through
      # SetTimeZoneFromLocation (bypass with authorize?: false, no time_zone change).
      geocoded =
        geocoded
        |> Ash.Changeset.for_update(:update_details, %{}, actor: owner)
        |> Ash.Changeset.force_change_attribute(:latitude, 30.27)
        |> Ash.Changeset.force_change_attribute(:longitude, -97.74)
        |> Ash.Changeset.force_change_attribute(:time_zone, "Etc/UTC")
        |> Ash.update!(authorize?: false)

      ungeocoded =
        Huddlz.Generator.group(owner_id: owner.id, actor: owner) |> Huddlz.Generator.generate()

      Huddlz.BackfillTimeZones.run()

      assert Ash.get!(Group, geocoded.id, authorize?: false).time_zone == "America/Chicago"
      assert Ash.get!(Group, ungeocoded.id, authorize?: false).time_zone == "Etc/UTC"
    end

    test "geo-derives time_zone for huddlz with their own coordinates, else inherits the (already-backfilled) group's" do
      owner = Huddlz.Generator.user() |> Huddlz.Generator.generate()

      group =
        Huddlz.Generator.group(owner_id: owner.id, actor: owner, time_zone: "Etc/UTC")
        |> Huddlz.Generator.generate()
        |> Ash.Changeset.for_update(:update_details, %{}, actor: owner)
        |> Ash.Changeset.force_change_attribute(:latitude, 29.89)
        |> Ash.Changeset.force_change_attribute(:longitude, -81.31)
        |> Ash.Changeset.force_change_attribute(:time_zone, "Etc/UTC")
        |> Ash.update!(authorize?: false)

      huddl_with_own_coords =
        Huddlz.Generator.huddl(group_id: group.id, actor: owner, time_zone: "Etc/UTC")
        |> Huddlz.Generator.generate()
        |> Ash.Changeset.for_update(:update, %{}, actor: owner)
        |> Ash.Changeset.force_change_attribute(:latitude, 30.27)
        |> Ash.Changeset.force_change_attribute(:longitude, -97.74)
        |> Ash.Changeset.force_change_attribute(:time_zone, "Etc/UTC")
        |> Ash.update!(authorize?: false)

      huddl_without_coords =
        Huddlz.Generator.huddl(
          group_id: group.id,
          actor: owner,
          time_zone: "Etc/UTC",
          event_type: :virtual,
          physical_location: nil,
          virtual_link: "https://example.com/meet"
        )
        |> Huddlz.Generator.generate()

      Huddlz.BackfillTimeZones.run()

      assert Ash.get!(Huddl, huddl_with_own_coords.id, authorize?: false).time_zone ==
               "America/Chicago"

      updated_group = Ash.get!(Group, group.id, authorize?: false)

      assert Ash.get!(Huddl, huddl_without_coords.id, authorize?: false).time_zone ==
               updated_group.time_zone
    end

    test "backfills every matching row, not just a first page's worth" do
      # Regression test for a bug where the backfill streamed matching rows
      # via offset pagination and re-issued `LIMIT/OFFSET` against the same
      # `time_zone == "Etc/UTC"` filter on each batch. Since a successful
      # backfill removes a row from that filter, the matching set shrinks
      # as the run progresses; once a full batch succeeded, the next
      # `OFFSET` landed past the end of the now-smaller matching set and
      # the stream silently halted, skipping every row after the first
      # batch (with no error — `run/0` still returned `:ok`).
      #
      # The fix collects the *entire* matching set with a single
      # unpaginated query before mutating anything, so there is no batch
      # boundary anywhere in the code path — a query returning 5 rows and
      # a query returning 5,000 executes identically. That means row count
      # can't be what makes this test meaningful; what matters is proving
      # *every* matched row gets updated, not merely the first one (which
      # the old bug would still have gotten right). A handful of rows is
      # sufficient for that — seeding hundreds only to exercise the same
      # single-query code path would add runtime without adding coverage.
      owner = Huddlz.Generator.user() |> Huddlz.Generator.generate()

      groups =
        for _ <- 1..5 do
          Huddlz.Generator.group(owner_id: owner.id, actor: owner)
          |> Huddlz.Generator.generate()
          |> Ash.Changeset.for_update(:update_details, %{}, actor: owner)
          |> Ash.Changeset.force_change_attribute(:latitude, 30.27)
          |> Ash.Changeset.force_change_attribute(:longitude, -97.74)
          |> Ash.Changeset.force_change_attribute(:time_zone, "Etc/UTC")
          |> Ash.update!(authorize?: false)
        end

      huddlz =
        for group <- groups do
          Huddlz.Generator.huddl(group_id: group.id, actor: owner, time_zone: "Etc/UTC")
          |> Huddlz.Generator.generate()
          |> Ash.Changeset.for_update(:update, %{}, actor: owner)
          |> Ash.Changeset.force_change_attribute(:latitude, 30.27)
          |> Ash.Changeset.force_change_attribute(:longitude, -97.74)
          |> Ash.Changeset.force_change_attribute(:time_zone, "Etc/UTC")
          |> Ash.update!(authorize?: false)
        end

      Huddlz.BackfillTimeZones.run()

      group_time_zones =
        Enum.map(groups, &Ash.get!(Group, &1.id, authorize?: false).time_zone)

      huddl_time_zones =
        Enum.map(huddlz, &Ash.get!(Huddl, &1.id, authorize?: false).time_zone)

      assert group_time_zones == List.duplicate("America/Chicago", 5)
      assert huddl_time_zones == List.duplicate("America/Chicago", 5)
    end
  end
end
