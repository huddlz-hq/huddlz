defmodule Huddlz.Geocoding.Google do
  @moduledoc """
  Google Maps Geocoding API implementation.
  """

  @behaviour Huddlz.Geocoding

  @geocoding_url "https://maps.googleapis.com/maps/api/geocode/json"

  # Geocoding runs in the request path; cap how long a slow Google response
  # can hold a connection, and don't let Req's default retry-with-backoff
  # multiply that wait.
  @req_options [receive_timeout: :timer.seconds(5), retry: false]

  @accepted_types ~w(
    street_address route premise subpremise
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

  @impl true
  def reverse_geocode(lat, lng) when is_number(lat) and is_number(lng) do
    opts =
      [params: [latlng: "#{lat},#{lng}", key: api_key()]] ++ @req_options ++ req_test_options()

    case Req.get(@geocoding_url, opts) do
      {:ok, %{status: 200, body: %{"status" => "OK", "results" => results}}} ->
        results
        |> Enum.find(&addressable_result?/1)
        |> case do
          %{"formatted_address" => address, "place_id" => place_id} ->
            {:ok, %{formatted_address: address, place_id: place_id}}

          nil ->
            {:error, :not_found}
        end

      {:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}} ->
        {:error, :not_found}

      {:ok, %{status: 200, body: %{"status" => status}}} ->
        {:error, {:api_error, status}}

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp do_geocode(address) do
    address
    |> fetch_coordinates(api_key())
    |> parse_response()
  end

  defp fetch_coordinates(address, key) do
    opts = [params: [address: address, key: key]] ++ @req_options ++ req_test_options()
    Req.get(@geocoding_url, opts)
  end

  defp req_test_options do
    case Application.get_env(:huddlz, :geocoding_req_plug) do
      nil -> []
      plug -> [plug: plug]
    end
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

  # Only a street-level (or finer) result names one address; a locality or
  # region would be no more specific than what a map search already has.
  defp addressable_result?(%{"types" => types}) do
    Enum.any?(types, &(&1 in ~w(street_address premise subpremise)))
  end

  defp addressable_result?(_), do: false

  defp api_key do
    Application.get_env(:huddlz, :google_maps)[:api_key]
  end
end
