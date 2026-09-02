defmodule Huddlz.Communities.Huddl.Changes.DefaultLocationFromGroupTest do
  use Huddlz.DataCase, async: true

  import Mox
  import Huddlz.Generator

  setup :verify_on_exit!

  describe "virtual huddlz inherit group location" do
    test "virtual huddl gets coordinates from group" do
      # Stub geocoding for group creation
      stub(Huddlz.MockGeocoding, :geocode, fn _address ->
        {:ok, %{latitude: 30.2672, longitude: -97.7431}}
      end)

      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            location: "Austin, TX",
            actor: owner,
            geocode?: true
          )
        )

      # Verify group got geocoded
      assert group.latitude == 30.2672
      assert group.longitude == -97.7431

      # Now create a virtual huddl - geocode won't fire for virtual_link, but
      # DefaultLocationFromGroup should kick in
      virtual_huddl =
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

      assert virtual_huddl.latitude == 30.2672
      assert virtual_huddl.longitude == -97.7431
    end

    test "in-person huddl uses its saved venue location" do
      stub(Huddlz.MockGeocoding, :geocode, fn
        "Austin, TX" -> {:ok, %{latitude: 30.2672, longitude: -97.7431}}
        "Houston, TX" -> {:ok, %{latitude: 29.7604, longitude: -95.3698}}
        _ -> {:error, :not_found}
      end)

      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            location: "Austin, TX",
            actor: owner,
            geocode?: true
          )
        )

      venue =
        generate(
          group_location(
            group_id: group.id,
            actor: owner,
            address: "Houston, TX",
            latitude: 29.7604,
            longitude: -95.3698
          )
        )

      in_person_huddl =
        generate(
          huddl(
            event_type: :in_person,
            physical_location: "Houston, TX",
            group_location_id: venue.id,
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      # Should have Houston coordinates, not Austin
      assert in_person_huddl.latitude == 29.7604
      assert in_person_huddl.longitude == -95.3698
    end

    test "virtual huddl with group that has no coordinates stays nil" do
      owner = generate(user(role: :user))

      group =
        generate(
          group(owner_id: owner.id, is_public: true, location: "Legacy Place", actor: owner)
        )
        |> Ash.Changeset.for_update(:update_details, %{}, actor: owner)
        |> Ash.Changeset.force_change_attribute(:latitude, nil)
        |> Ash.Changeset.force_change_attribute(:longitude, nil)
        |> Ash.update!()

      assert is_nil(group.latitude)
      assert is_nil(group.longitude)

      virtual_huddl =
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

      assert is_nil(virtual_huddl.latitude)
      assert is_nil(virtual_huddl.longitude)
    end

    test "hybrid huddl uses its saved venue rather than the group location" do
      stub(Huddlz.MockGeocoding, :geocode, fn
        "Austin, TX" -> {:ok, %{latitude: 30.2672, longitude: -97.7431}}
        _ -> {:error, :not_found}
      end)

      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            location: "Austin, TX",
            actor: owner,
            geocode?: true
          )
        )

      assert group.latitude == 30.2672

      venue =
        generate(
          group_location(
            group_id: group.id,
            actor: owner,
            address: "Unknown Place",
            latitude: 0.0,
            longitude: 0.0
          )
        )

      # Hybrid huddl with no physical_location — geocoding will fail,
      # but DefaultLocationFromGroup should NOT kick in (only for virtual)
      hybrid_huddl =
        generate(
          huddl(
            event_type: :hybrid,
            virtual_link: "https://zoom.us/test",
            physical_location: "Unknown Place",
            group_location_id: venue.id,
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      assert hybrid_huddl.latitude == venue.latitude
      assert hybrid_huddl.longitude == venue.longitude
    end
  end
end
