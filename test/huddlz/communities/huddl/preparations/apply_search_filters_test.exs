defmodule Huddlz.Communities.Huddl.Preparations.ApplySearchFiltersTest do
  use Huddlz.DataCase, async: true

  import Mox
  import Huddlz.Generator

  setup :verify_on_exit!

  setup do
    # Stub geocoding to return nil (no coordinates) by default
    stub(Huddlz.MockGeocoding, :geocode, fn _address -> {:error, :not_found} end)

    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    # Create huddlz at known locations using seed_generator
    austin_huddl =
      generate(
        huddl_at_location(
          title: "Austin Meetup",
          latitude: 30.2672,
          longitude: -97.7431,
          group_id: group.id,
          creator_id: owner.id
        )
      )

    houston_huddl =
      generate(
        huddl_at_location(
          title: "Houston Meetup",
          latitude: 29.7604,
          longitude: -95.3698,
          group_id: group.id,
          creator_id: owner.id
        )
      )

    dallas_huddl =
      generate(
        huddl_at_location(
          title: "Dallas Meetup",
          latitude: 32.7767,
          longitude: -96.7970,
          group_id: group.id,
          creator_id: owner.id
        )
      )

    no_location_huddl =
      generate(
        huddl_at_location(
          title: "No Location Meetup",
          latitude: nil,
          longitude: nil,
          group_id: group.id,
          creator_id: owner.id
        )
      )

    %{
      owner: owner,
      group: group,
      austin_huddl: austin_huddl,
      houston_huddl: houston_huddl,
      dallas_huddl: dallas_huddl,
      no_location_huddl: no_location_huddl
    }
  end

  describe "location filter" do
    test "filters huddlz within distance radius", %{austin_huddl: austin, owner: owner} do
      # Search near Austin with 50 mile radius
      {:ok, %{results: results}} =
        Huddlz.Communities.search_huddlz(
          nil,
          :upcoming,
          nil,
          30.2672,
          -97.7431,
          50,
          actor: owner,
          page: [limit: 20, offset: 0, count: true]
        )

      ids = Enum.map(results, & &1.id)
      assert austin.id in ids
    end

    test "excludes huddlz outside distance radius", %{
      houston_huddl: houston,
      owner: owner
    } do
      # Search near Austin with 10 mile radius - Houston (~162 mi) should be excluded
      {:ok, %{results: results}} =
        Huddlz.Communities.search_huddlz(
          nil,
          :upcoming,
          nil,
          30.2672,
          -97.7431,
          10,
          actor: owner,
          page: [limit: 20, offset: 0, count: true]
        )

      ids = Enum.map(results, & &1.id)
      refute houston.id in ids
    end

    test "excludes huddlz with no coordinates from location search", %{
      no_location_huddl: no_loc,
      owner: owner
    } do
      {:ok, %{results: results}} =
        Huddlz.Communities.search_huddlz(
          nil,
          :upcoming,
          nil,
          30.2672,
          -97.7431,
          100,
          actor: owner,
          page: [limit: 20, offset: 0, count: true]
        )

      ids = Enum.map(results, & &1.id)
      refute no_loc.id in ids
    end

    test "returns all huddlz when no location filter is applied", %{
      austin_huddl: austin,
      houston_huddl: houston,
      dallas_huddl: dallas,
      no_location_huddl: no_loc,
      owner: owner
    } do
      {:ok, %{results: results}} =
        Huddlz.Communities.search_huddlz(
          nil,
          :upcoming,
          nil,
          nil,
          nil,
          nil,
          actor: owner,
          page: [limit: 20, offset: 0, count: true]
        )

      ids = Enum.map(results, & &1.id)
      assert austin.id in ids
      assert houston.id in ids
      assert dallas.id in ids
      assert no_loc.id in ids
    end

    test "wider radius includes more huddlz", %{owner: owner} do
      {:ok, %{results: near_results}} =
        Huddlz.Communities.search_huddlz(
          nil,
          :upcoming,
          nil,
          30.2672,
          -97.7431,
          10,
          actor: owner,
          page: [limit: 20, offset: 0, count: true]
        )

      {:ok, %{results: far_results}} =
        Huddlz.Communities.search_huddlz(
          nil,
          :upcoming,
          nil,
          30.2672,
          -97.7431,
          100,
          actor: owner,
          page: [limit: 20, offset: 0, count: true]
        )

      assert length(far_results) >= length(near_results)
    end
  end
end
