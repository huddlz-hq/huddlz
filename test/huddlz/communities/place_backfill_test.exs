defmodule Huddlz.Communities.PlaceBackfillTest do
  use Huddlz.DataCase, async: false

  @moduletag :place_backfill

  import Huddlz.Generator
  import Mox

  alias Huddlz.Communities.GroupLocation
  alias Huddlz.Communities.PlaceBackfill

  setup :verify_on_exit!

  setup do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    legacy =
      generate(
        group_location(
          group_id: group.id,
          address: "Old Saint Augustine Road, Jacksonville, FL, USA",
          latitude: 30.1712,
          longitude: -81.6021,
          actor: owner
        )
      )

    %{owner: owner, group: group, legacy: legacy}
  end

  test "resolves a saved location to its full address and place id", %{legacy: legacy} do
    expect(Huddlz.MockGeocoding, :reverse_geocode, fn 30.1712, -81.6021 ->
      {:ok,
       %{
         formatted_address: "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA",
         place_id: "place-9801"
       }}
    end)

    assert %{resolved: 1, skipped: 0} = PlaceBackfill.run()

    location = Ash.get!(GroupLocation, legacy.id, authorize?: false)
    assert location.address == "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    assert location.place_id == "place-9801"
  end

  test "gives the huddlz saved from the location its place id", %{
    owner: owner,
    group: group,
    legacy: legacy
  } do
    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          group_location_id: legacy.id,
          actor: owner
        )
      )

    expect(Huddlz.MockGeocoding, :reverse_geocode, fn _, _ ->
      {:ok,
       %{
         formatted_address: "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA",
         place_id: "place-9801"
       }}
    end)

    PlaceBackfill.run()

    reloaded = Ash.get!(Huddlz.Communities.Huddl, huddl.id, authorize?: false)
    assert reloaded.place_id == "place-9801"
    assert reloaded.physical_location == huddl.physical_location
  end

  test "leaves locations Google cannot resolve untouched", %{legacy: legacy} do
    expect(Huddlz.MockGeocoding, :reverse_geocode, fn _, _ -> {:error, :not_found} end)

    assert %{resolved: 0, skipped: 1} = PlaceBackfill.run()

    location = Ash.get!(GroupLocation, legacy.id, authorize?: false)
    assert location.address == "Old Saint Augustine Road, Jacksonville, FL, USA"
    assert is_nil(location.place_id)
  end

  test "a dry run reports without writing", %{legacy: legacy} do
    expect(Huddlz.MockGeocoding, :reverse_geocode, fn _, _ ->
      {:ok, %{formatted_address: "9801 Old St Augustine Rd", place_id: "place-9801"}}
    end)

    assert %{resolved: 1} = PlaceBackfill.run(dry_run: true)

    assert is_nil(Ash.get!(GroupLocation, legacy.id, authorize?: false).place_id)
  end

  test "skips locations that already have a place id", %{group: group, owner: owner} do
    generate(group_location(group_id: group.id, place_id: "already", actor: owner))
    expect(Huddlz.MockGeocoding, :reverse_geocode, 1, fn _, _ -> {:error, :not_found} end)

    # Only the legacy location (no place id) is looked up.
    assert %{resolved: 0, skipped: 1} = PlaceBackfill.run()
  end
end
