defmodule Huddlz.Geocoding.Google do
  @moduledoc """
  Google Maps Geocoding API implementation.
  """

  @behaviour Huddlz.Geocoding

  @geocoding_url "https://maps.googleapis.com/maps/api/geocode/json"

  @impl true
  def geocode(address) when is_binary(address) and byte_size(address) > 0 do
    case api_key() do
      nil ->
        {:error, :no_api_key}

      key ->
        case Req.get(@geocoding_url, params: [address: address, key: key]) do
          {:ok, %{status: 200, body: %{"status" => "OK", "results" => [result | _]}}} ->
            %{"geometry" => %{"location" => %{"lat" => lat, "lng" => lng}}} = result
            {:ok, %{latitude: lat, longitude: lng}}

          {:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}} ->
            {:error, :not_found}

          {:ok, %{status: 200, body: %{"status" => status}}} ->
            {:error, {:api_error, status}}

          {:error, reason} ->
            {:error, {:request_failed, reason}}
        end
    end
  end

  def geocode(_), do: {:error, :invalid_address}

  defp api_key do
    Application.get_env(:huddlz, :google_maps)[:api_key]
  end
end
