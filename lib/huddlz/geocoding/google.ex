defmodule Huddlz.Geocoding.Google do
  @moduledoc """
  Google Places API implementation for geocoding.

  Uses the Places Autocomplete API for address suggestions and
  the Place Details API for full address information including coordinates.
  """

  @behaviour Huddlz.Geocoding.Behaviour

  @autocomplete_url "https://maps.googleapis.com/maps/api/place/autocomplete/json"
  @details_url "https://maps.googleapis.com/maps/api/place/details/json"

  @impl true
  def autocomplete(query, opts \\ []) do
    case api_key() do
      nil ->
        {:error, :api_key_not_configured}

      key ->
        params = build_autocomplete_params(query, key, opts)

        case Req.get(@autocomplete_url, params: params) do
          {:ok, %{status: 200, body: body}} ->
            handle_autocomplete_response(body)

          {:ok, %{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @impl true
  def place_details(place_id) do
    case api_key() do
      nil ->
        {:error, :api_key_not_configured}

      key ->
        params = build_details_params(place_id, key)

        case Req.get(@details_url, params: params) do
          {:ok, %{status: 200, body: body}} ->
            handle_details_response(body)

          {:ok, %{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp build_autocomplete_params(query, key, opts) do
    base_params = %{
      input: query,
      key: key,
      types: "address"
    }

    # Allow optional country restriction
    case Keyword.get(opts, :country) do
      nil -> base_params
      country -> Map.put(base_params, :components, "country:#{country}")
    end
  end

  defp build_details_params(place_id, key) do
    %{
      place_id: place_id,
      key: key,
      fields: "formatted_address,geometry,address_components,place_id"
    }
  end

  defp handle_autocomplete_response(%{"status" => "OK", "predictions" => predictions}) do
    suggestions =
      Enum.map(predictions, fn prediction ->
        %{
          place_id: prediction["place_id"],
          description: prediction["description"]
        }
      end)

    {:ok, suggestions}
  end

  defp handle_autocomplete_response(%{"status" => "ZERO_RESULTS"}) do
    {:ok, []}
  end

  defp handle_autocomplete_response(%{"status" => status, "error_message" => message}) do
    {:error, {:api_error, status, message}}
  end

  defp handle_autocomplete_response(%{"status" => status}) do
    {:error, {:api_error, status, nil}}
  end

  defp handle_details_response(%{"status" => "OK", "result" => result}) do
    address_data = %{
      formatted_address: result["formatted_address"],
      latitude: get_in(result, ["geometry", "location", "lat"]),
      longitude: get_in(result, ["geometry", "location", "lng"]),
      place_id: result["place_id"],
      street_number: extract_component(result, "street_number"),
      street_name: extract_component(result, "route"),
      city:
        extract_component(result, "locality") ||
          extract_component(result, "sublocality_level_1"),
      state: extract_component(result, "administrative_area_level_1", :short),
      postal_code: extract_component(result, "postal_code"),
      country: extract_component(result, "country", :short),
      country_name: extract_component(result, "country")
    }

    {:ok, address_data}
  end

  defp handle_details_response(%{"status" => status, "error_message" => message}) do
    {:error, {:api_error, status, message}}
  end

  defp handle_details_response(%{"status" => status}) do
    {:error, {:api_error, status, nil}}
  end

  defp extract_component(result, type, name_type \\ :long) do
    components = result["address_components"] || []

    case Enum.find(components, fn c -> type in c["types"] end) do
      nil ->
        nil

      component ->
        case name_type do
          :short -> component["short_name"]
          :long -> component["long_name"]
        end
    end
  end

  defp api_key do
    case Application.get_env(:huddlz, :google_maps) do
      nil -> nil
      config -> Keyword.get(config, :api_key)
    end
  end
end
