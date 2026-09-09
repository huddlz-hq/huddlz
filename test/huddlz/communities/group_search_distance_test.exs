defmodule Huddlz.Communities.GroupSearchDistanceTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities

  test "distance limits group home locations and an omitted radius defaults to 25 miles" do
    actor = generate(user())
    austin = generate(group(latitude: 30.2672, longitude: -97.7431, actor: actor))
    # San Marcos is approximately 29 miles from Austin.
    san_marcos = generate(group(latitude: 29.8833, longitude: -97.9414, actor: actor))
    houston = generate(group(latitude: 29.7604, longitude: -95.3698, actor: actor))
    origin = %{search_latitude: 30.2672, search_longitude: -97.7431}

    assert [result] = Communities.search_groups!(nil, origin)
    assert result.id == austin.id

    assert [result] = Communities.search_groups!(nil, Map.put(origin, :distance_miles, nil))
    assert result.id == austin.id

    results = Communities.search_groups!(nil, Map.put(origin, :distance_miles, 50))
    assert MapSet.new(results, & &1.id) == MapSet.new([austin.id, san_marcos.id])

    results = Communities.search_groups!(nil, %{distance_miles: 5})
    assert MapSet.new(results, & &1.id) == MapSet.new([austin.id, san_marcos.id, houston.id])
  end

  test "invalid distances return validation errors" do
    for distance <- [4, 101] do
      assert {:error, %Ash.Error.Invalid{}} =
               Communities.search_groups(nil, %{
                 search_latitude: 30.2672,
                 search_longitude: -97.7431,
                 distance_miles: distance
               })
    end
  end
end
