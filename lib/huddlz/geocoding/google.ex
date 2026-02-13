defmodule Huddlz.Geocoding.Google do
  @moduledoc """
  Google Maps Geocoding API implementation.
  """

  @behaviour Huddlz.Geocoding

  @geocoding_url "https://maps.googleapis.com/maps/api/geocode/json"

  @accepted_types ~w(
    locality sublocality neighborhood postal_code
    administrative_area_level_2 administrative_area_level_3
    sublocality_level_1 sublocality_level_2
  )

  @impl true
  def geocode(address) when is_binary(address) do
    address = String.trim(address)

    if byte_size(address) == 0 do
      {:error, :invalid_address}
    else
      do_geocode(address)
    end
  end

  def geocode(_), do: {:error, :invalid_address}

  defp do_geocode(address) do
    address
    |> fetch_coordinates(api_key())
    |> parse_response()
  end

  defp fetch_coordinates(address, key) do
    Req.get(@geocoding_url, params: [address: address, key: key])
  end

  defp parse_response({:ok, %{status: 200, body: %{"status" => "OK", "results" => results}}}) do
    case Enum.find(results, &geographic_result?/1) do
      %{"geometry" => %{"location" => %{"lat" => lat, "lng" => lng}}} ->
        {:ok, %{latitude: lat, longitude: lng}}

      nil ->
        {:error, :not_found}
    end
  end

  defp parse_response({:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}}) do
    {:error, :not_found}
  end

  defp parse_response({:ok, %{status: 200, body: %{"status" => status}}}) do
    {:error, {:api_error, status}}
  end

  defp parse_response({:error, reason}) do
    {:error, {:request_failed, reason}}
  end

  defp geographic_result?(%{"types" => types}) do
    Enum.any?(types, &(&1 in @accepted_types))
  end

  defp geographic_result?(_), do: false

  defp api_key do
    Application.get_env(:huddlz, :google_maps)[:api_key]
  end
end
