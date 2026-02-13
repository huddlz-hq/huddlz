defmodule Huddlz.Communities.Huddl.Changes.GeocodeLocationTest do
  use Huddlz.DataCase, async: true

  import Mox
  import Huddlz.Generator

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

    test "geocoding failure sets lat/lng to nil" do
      stub(Huddlz.MockGeocoding, :geocode, fn _address ->
        {:error, :not_found}
      end)

      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

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
  end
end
