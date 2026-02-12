defmodule Huddlz.Geocoding.Google do
  @moduledoc """
  Google Maps Geocoding API implementation.
  """

  @behaviour Huddlz.Geocoding

  @geocoding_url "https://maps.googleapis.com/maps/api/geocode/json"

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

  defp parse_response({:ok, %{status: 200, body: %{"status" => "OK", "results" => [result | _]}}}) do
    %{"geometry" => %{"location" => %{"lat" => lat, "lng" => lng}}} = result
    {:ok, %{latitude: lat, longitude: lng}}
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

  defp api_key do
    Application.get_env(:huddlz, :google_maps)[:api_key]
  end
end
