defmodule Huddlz.Communities.Huddl.Changes.ApplyProvidedCoordinatesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl

  import Mox

  setup :verify_on_exit!

  describe "apply_provided_coordinates change" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      tomorrow = Date.utc_today() |> Date.add(1)

      {:ok, %{owner: owner, group: group, tomorrow: tomorrow}}
    end

    test "when provided_latitude and provided_longitude are given, sets coordinates and skips geocoding",
         %{owner: owner, group: group, tomorrow: tomorrow} do
      # Geocoding should NOT be called when coordinates are provided
      Mox.expect(Huddlz.MockGeocoding, :geocode, 0, fn _ ->
        {:ok, %{latitude: 0, longitude: 0}}
      end)

      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(:create, %{
                 title: "Test Huddl",
                 description: "Test",
                 date: tomorrow,
                 start_time: ~T[14:00:00],
                 duration_minutes: 60,
                 event_type: :in_person,
                 physical_location: "100 Main St, Austin, TX",
                 group_id: group.id,
                 creator_id: owner.id,
                 provided_latitude: 30.27,
                 provided_longitude: -97.74
               })
               |> Ash.create(actor: owner)

      assert huddl.latitude == 30.27
      assert huddl.longitude == -97.74
    end

    test "when coordinates NOT provided, geocoding runs normally",
         %{owner: owner, group: group, tomorrow: tomorrow} do
      Mox.expect(Huddlz.MockGeocoding, :geocode, fn "456 Oak Ave, Dallas, TX" ->
        {:ok, %{latitude: 32.78, longitude: -96.80}}
      end)

      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(:create, %{
                 title: "Geocoded Huddl",
                 description: "Test",
                 date: tomorrow,
                 start_time: ~T[14:00:00],
                 duration_minutes: 60,
                 event_type: :in_person,
                 physical_location: "456 Oak Ave, Dallas, TX",
                 group_id: group.id,
                 creator_id: owner.id
               })
               |> Ash.create(actor: owner)

      assert huddl.latitude == 32.78
      assert huddl.longitude == -96.80
    end

    test "partial coordinates (only lat) are ignored, geocoding runs",
         %{owner: owner, group: group, tomorrow: tomorrow} do
      Mox.expect(Huddlz.MockGeocoding, :geocode, fn _ ->
        {:ok, %{latitude: 29.76, longitude: -95.37}}
      end)

      assert {:ok, huddl} =
               Huddl
               |> Ash.Changeset.for_create(:create, %{
                 title: "Partial Coords",
                 description: "Test",
                 date: tomorrow,
                 start_time: ~T[14:00:00],
                 duration_minutes: 60,
                 event_type: :in_person,
                 physical_location: "789 Elm St, Houston, TX",
                 group_id: group.id,
                 creator_id: owner.id,
                 provided_latitude: 30.27
               })
               |> Ash.create(actor: owner)

      assert huddl.latitude == 29.76
      assert huddl.longitude == -95.37
    end
  end
end
