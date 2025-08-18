defmodule Huddlz.Geocoding.GoogleMaps do
  @moduledoc """
  Google Maps geocoding implementation using the Google Geocoding API.
  """
  @behaviour Huddlz.Geocoding.Behaviour

  @geocoding_url "https://maps.googleapis.com/maps/api/geocode/json"

  @impl true
  def geocode(address) when is_binary(address) do
    api_key = get_api_key()
    
    case Req.get(@geocoding_url, params: %{address: address, key: api_key}) do
      {:ok, %{status: 200, body: body}} ->
        parse_geocoding_response(body)
      
      {:ok, %{status: status}} ->
        {:error, "Geocoding API returned status #{status}"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def reverse_geocode(lat, lng) when is_number(lat) and is_number(lng) do
    api_key = get_api_key()
    
    case Req.get(@geocoding_url, params: %{latlng: "#{lat},#{lng}", key: api_key}) do
      {:ok, %{status: 200, body: body}} ->
        parse_reverse_geocoding_response(body)
      
      {:ok, %{status: status}} ->
        {:error, "Reverse geocoding API returned status #{status}"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_geocoding_response(%{"status" => "OK", "results" => [result | _]}) do
    %{
      "geometry" => %{
        "location" => %{
          "lat" => lat,
          "lng" => lng
        }
      }
    } = result
    
    {:ok, %{lat: lat, lng: lng}}
  end

  defp parse_geocoding_response(%{"status" => "ZERO_RESULTS"}) do
    {:error, :not_found}
  end

  defp parse_geocoding_response(%{"status" => status, "error_message" => message}) do
    {:error, "Google Maps API error: #{status} - #{message}"}
  end

  defp parse_geocoding_response(%{"status" => status}) do
    {:error, "Google Maps API error: #{status}"}
  end

  defp parse_reverse_geocoding_response(%{"status" => "OK", "results" => [result | _]}) do
    {:ok, result["formatted_address"]}
  end

  defp parse_reverse_geocoding_response(%{"status" => "ZERO_RESULTS"}) do
    {:error, :not_found}
  end

  defp parse_reverse_geocoding_response(%{"status" => status}) do
    {:error, "Google Maps API error: #{status}"}
  end

  defp get_api_key do
    System.get_env("GOOGLE_MAPS_API_KEY") ||
      raise "GOOGLE_MAPS_API_KEY environment variable is not set"
  end
end