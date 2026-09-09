defmodule HuddlzWeb.Api.Json.ProfileTest do
  use HuddlzWeb.ApiCase, async: true

  @moduletag :api_search_defaults

  test "OpenAPI describes private profile search defaults without exposing user fields", %{
    conn: conn
  } do
    spec = conn |> get("/api/json/open_api") |> response(200) |> Jason.decode!()

    profile =
      get_in(spec, [
        "paths",
        "/api/json/profile",
        "get",
        "responses",
        "200",
        "content",
        "application/vnd.api+json",
        "schema"
      ])

    assert profile["properties"]["id"]["type"] == "string"
    defaults = profile["properties"]["search_defaults"]
    assert defaults["properties"]["distance_miles"]["type"] == "integer"
    location = defaults["properties"]["home_location"]
    assert %{"type" => "null"} in location["anyOf"]

    assert Enum.any?(
             location["anyOf"],
             &match?(
               %{"properties" => %{"latitude" => _, "longitude" => _, "time_zone" => _}},
               &1
             )
           )

    refute Map.has_key?(spec["components"]["schemas"], "user")
  end
end
