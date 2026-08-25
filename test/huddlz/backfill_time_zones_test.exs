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
  end
end
