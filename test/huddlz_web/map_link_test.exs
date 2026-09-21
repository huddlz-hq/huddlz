defmodule HuddlzWeb.MapLinkTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.MapLink

  @base "https://www.google.com/maps/search/?api=1&query="

  test "a place id identifies the exact place, with the address as the query" do
    huddl = %{
      physical_location: "1 Main St, Austin, TX",
      place_id: "abc",
      latitude: 1.5,
      longitude: 2.5
    }

    assert MapLink.url(huddl) == @base <> "1+Main+St%2C+Austin%2C+TX&query_place_id=abc"
  end

  test "coordinates identify the place when there is no place id" do
    huddl = %{physical_location: "Main St", place_id: nil, latitude: 30.1712, longitude: -81.6021}

    assert MapLink.url(huddl) == @base <> "30.1712%2C-81.6021"
  end

  test "the address text is used when there is neither place id nor coordinates" do
    huddl = %{physical_location: "Main St, Austin", place_id: nil, latitude: nil, longitude: nil}

    assert MapLink.url(huddl) == @base <> "Main+St%2C+Austin"
  end
end
