defmodule HuddlzWeb.MapLink do
  @moduledoc """
  Builds the Google Maps link and embedded map for a huddl's physical location.

  A place id opens exactly the saved place. Without one, the coordinates
  pinpoint it; a bare street and city would match many places. The address
  text is the last resort for huddlz with neither.
  """

  @search_url "https://www.google.com/maps/search/?api=1&query="
  @embed_url "https://www.google.com/maps/embed/v1/place"

  @spec url(map()) :: String.t()
  def url(%{place_id: place_id, physical_location: address}) when is_binary(place_id) do
    @search_url <> encode(address) <> "&query_place_id=" <> encode(place_id)
  end

  def url(%{latitude: lat, longitude: lng}) when is_number(lat) and is_number(lng) do
    @search_url <> encode("#{lat},#{lng}")
  end

  def url(%{physical_location: address}), do: @search_url <> encode(address)

  @doc """
  The Maps Embed API address for a huddl's map, or `nil` when no embed key is
  configured.
  """
  @spec embed_url(map()) :: String.t() | nil
  def embed_url(huddl) do
    case embed_key() do
      key when is_binary(key) and key != "" ->
        @embed_url <> "?" <> URI.encode_query(key: key, q: embed_query(huddl))

      _ ->
        nil
    end
  end

  defp embed_query(%{place_id: place_id}) when is_binary(place_id), do: "place_id:" <> place_id

  defp embed_query(%{latitude: lat, longitude: lng}) when is_number(lat) and is_number(lng),
    do: "#{lat},#{lng}"

  defp embed_query(%{physical_location: address}), do: to_string(address)

  defp embed_key, do: Application.get_env(:huddlz, :google_maps, [])[:embed_key]

  defp encode(value), do: URI.encode_www_form(to_string(value))
end
