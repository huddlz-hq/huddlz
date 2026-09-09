defmodule Huddlz.Communities.Group.Preparations.FilterByDistance do
  @moduledoc "Filters groups by the distance from a search point to their home location."
  use Ash.Resource.Preparation

  require Ash.Query

  @meters_per_mile 1609.344

  @impl true
  def prepare(query, _opts, _context) do
    latitude = Ash.Query.get_argument(query, :search_latitude)
    longitude = Ash.Query.get_argument(query, :search_longitude)
    distance = Ash.Query.get_argument(query, :distance_miles) || 25

    if is_number(latitude) and is_number(longitude) and is_integer(distance) do
      meters = distance * @meters_per_mile

      Ash.Query.filter(
        query,
        fragment(
          "ST_DWithin(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?)",
          longitude,
          latitude,
          ^longitude,
          ^latitude,
          ^meters
        )
      )
    else
      query
    end
  end
end
