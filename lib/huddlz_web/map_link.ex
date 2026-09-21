defmodule HuddlzWeb.MapLink do
  @moduledoc """
  Builds the Google Maps link for a huddl's physical location.

  A place id opens exactly the saved place. Without one, the coordinates
  pinpoint it; a bare street and city would match many places. The address
  text is the last resort for huddlz with neither.
  """

  @search_url "https://www.google.com/maps/search/?api=1&query="

  @spec url(map()) :: String.t()
  def url(%{place_id: place_id, physical_location: address}) when is_binary(place_id) do
    @search_url <> encode(address) <> "&query_place_id=" <> encode(place_id)
  end

  def url(%{latitude: lat, longitude: lng}) when is_number(lat) and is_number(lng) do
    @search_url <> encode("#{lat},#{lng}")
  end

  def url(%{physical_location: address}), do: @search_url <> encode(address)

  defp encode(value), do: URI.encode_www_form(to_string(value))
end
