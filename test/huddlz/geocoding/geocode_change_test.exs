defmodule Huddlz.Geocoding.GeocodeChangeTest do
  use Huddlz.DataCase, async: true

  import Mox
  import Huddlz.Generator

  alias Huddlz.Communities.Huddl
  alias Huddlz.Geocoding.Change, as: GeocodingChange

  setup :verify_on_exit!

  describe "geocode location change" do
    test "successful geocoding sets lat/lng" do
      stub(Huddlz.MockGeocoding, :geocode, fn
        "Austin, TX" -> {:ok, %{latitude: 30.2672, longitude: -97.7431}}
        _ -> {:error, :not_found}
      end)

      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      huddl =
        generate(
          huddl(
            event_type: :in_person,
            physical_location: "Austin, TX",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      assert huddl.latitude == 30.2672
      assert huddl.longitude == -97.7431
    end

    test "geocoding failure sets lat/lng to nil and stays quiet in test env" do
      stub(Huddlz.MockGeocoding, :geocode, fn _address ->
        {:error, :not_found}
      end)

      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          huddl =
            generate(
              huddl(
                event_type: :in_person,
                physical_location: "Nonexistent Place XYZ",
                group_id: group.id,
                creator_id: owner.id,
                actor: owner
              )
            )

          assert is_nil(huddl.latitude)
          assert is_nil(huddl.longitude)
        end)

      refute log =~ "Geocoding failed for"
    end

    test "nil physical_location does not trigger geocoding" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      # After group creation, set up an expect that geocode should NOT be called
      # for the virtual huddl with nil physical_location
      expect(Huddlz.MockGeocoding, :geocode, 0, fn _address ->
        {:ok, %{latitude: 30.2672, longitude: -97.7431}}
      end)

      huddl =
        generate(
          huddl(
            event_type: :virtual,
            virtual_link: "https://zoom.us/test",
            physical_location: nil,
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      assert is_struct(huddl, Huddlz.Communities.Huddl)
    end

    test "geocoding runs on update even when latitude/longitude already have values" do
      stub(Huddlz.MockGeocoding, :geocode, fn
        "Austin, TX" -> {:ok, %{latitude: 30.2672, longitude: -97.7431}}
        "Dallas, TX" -> {:ok, %{latitude: 32.7767, longitude: -96.7970}}
        _ -> {:error, :not_found}
      end)

      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      huddl =
        generate(
          huddl(
            event_type: :in_person,
            physical_location: "Austin, TX",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      assert huddl.latitude == 30.2672

      # Update the location — geocoding must run for the new address,
      # NOT be skipped because latitude/longitude already have values
      updated_huddl =
        huddl
        |> Ash.Changeset.for_update(:update, %{physical_location: "Dallas, TX"}, actor: owner)
        |> Ash.update!()

      assert updated_huddl.latitude == 32.7767
      assert updated_huddl.longitude == -96.7970
    end

    test "provided_latitude/longitude arguments bypass geocoding" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      # Set expectation AFTER group creation (which triggers its own geocoding).
      # Geocoding should NOT be called for the huddl when coordinates are provided.
      expect(Huddlz.MockGeocoding, :geocode, 0, fn _address ->
        {:ok, %{latitude: 0.0, longitude: 0.0}}
      end)

      future_date = Date.add(Date.utc_today(), 7)

      # Set private arguments BEFORE for_create (Ash requires this ordering)
      huddl =
        Huddl
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:provided_latitude, 40.7128)
        |> Ash.Changeset.set_argument(:provided_longitude, -74.0060)
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Test Huddl",
            event_type: :in_person,
            physical_location: "Some Address",
            date: future_date,
            start_time: ~T[14:00:00],
            duration_minutes: 60,
            creator_id: owner.id,
            group_id: group.id
          },
          actor: owner
        )
        |> Ash.create!()

      assert huddl.latitude == 40.7128
      assert huddl.longitude == -74.0060
    end

    test "geocode_if_changed geocodes when lat/lng attributes exist but provided arguments do not" do
      # This tests the exact bug: if geocode_if_changed checks changeset.attributes
      # for lat/lng instead of the provided_* arguments, it would skip geocoding
      # when a prior change in the pipeline (or pre-existing data) set lat/lng.
      stub(Huddlz.MockGeocoding, :geocode, fn
        "New Location" -> {:ok, %{latitude: 40.0, longitude: -74.0}}
        _ -> {:error, :not_found}
      end)

      # Build a changeset that already has lat/lng in attributes (simulating
      # a prior change in the pipeline having set them) AND is changing
      # physical_location — geocoding MUST still run.
      changeset =
        Huddl
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:latitude, 30.0)
        |> Ash.Changeset.force_change_attribute(:longitude, -97.0)
        |> Ash.Changeset.force_change_attribute(:physical_location, "New Location")

      result = GeocodingChange.geocode_if_changed(changeset, :physical_location)

      assert Ash.Changeset.get_attribute(result, :latitude) == 40.0
      assert Ash.Changeset.get_attribute(result, :longitude) == -74.0
    end
  end
end
