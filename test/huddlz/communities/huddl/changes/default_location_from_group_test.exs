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
        generate(group(owner_id: owner.id, is_public: true, location: "Austin, TX", actor: owner))

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

    test "in-person huddl uses its own geocoded location" do
      stub(Huddlz.MockGeocoding, :geocode, fn
        "Austin, TX" -> {:ok, %{latitude: 30.2672, longitude: -97.7431}}
        "Houston, TX" -> {:ok, %{latitude: 29.7604, longitude: -95.3698}}
        _ -> {:error, :not_found}
      end)

      owner = generate(user(role: :user))

      group =
        generate(group(owner_id: owner.id, is_public: true, location: "Austin, TX", actor: owner))

      in_person_huddl =
        generate(
          huddl(
            event_type: :in_person,
            physical_location: "Houston, TX",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner
          )
        )

      # Should have Houston coordinates, not Austin
      assert in_person_huddl.latitude == 29.7604
      assert in_person_huddl.longitude == -95.3698
    end
  end
end
