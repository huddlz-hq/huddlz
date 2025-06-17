defmodule Huddlz.Geocoding.Real do
  @moduledoc """
  Real geocoding implementation using OpenStreetMap's Nominatim API.
  """

  @behaviour Huddlz.Geocoding.Behaviour

  require Logger

  @base_url "https://nominatim.openstreetmap.org/search"
  @user_agent "Huddlz/1.0"

  @impl true
  def geocode(address) when is_binary(address) do
    with {:ok, encoded_address} <- encode_address(address),
         {:ok, response} <- make_request(encoded_address),
         {:ok, coordinates} <- parse_response(response) do
      {:ok, coordinates}
    else
      {:error, reason} ->
        Logger.warning("Geocoding failed for '#{address}': #{inspect(reason)}")
        {:error, reason}
    end
  end

  def geocode(nil), do: {:error, :no_address}
  def geocode(""), do: {:error, :no_address}

  @impl true
  def geocode_to_point(address) when is_binary(address) do
    case geocode(address) do
      {:ok, %{lat: lat, lng: lng}} ->
        {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}

      error ->
        error
    end
  end

  def geocode_to_point(_), do: {:error, :invalid_address}

  defp encode_address(address) do
    {:ok, URI.encode_www_form(address)}
  rescue
    _ -> {:error, :encoding_failed}
  end

  defp make_request(encoded_address) do
    url = "#{@base_url}?q=#{encoded_address}&format=json&limit=1"

    headers = [
      {"User-Agent", @user_agent},
      {"Accept", "application/json"}
    ]

    case :httpc.request(:get, {String.to_charlist(url), headers}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, status_code, _}, _, _}} ->
        {:error, {:http_error, status_code}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, []} ->
        {:error, :no_results}

      {:ok, [result | _]} ->
        lat = result["lat"] |> String.to_float()
        lng = result["lon"] |> String.to_float()
        {:ok, %{lat: lat, lng: lng}}

      {:ok, _} ->
        {:error, :unexpected_response}

      {:error, _} ->
        {:error, :parse_error}
    end
  end
end
