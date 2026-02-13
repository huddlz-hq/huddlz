defmodule Huddlz.Places.Google do
  @moduledoc """
  Google Places API (New) implementation for location autocomplete.
  """

  @behaviour Huddlz.Places

  @autocomplete_url "https://places.googleapis.com/v1/places:autocomplete"

  @impl true
  def autocomplete(query, _session_token) when is_binary(query) and byte_size(query) < 2 do
    {:ok, []}
  end

  def autocomplete(query, session_token) when is_binary(query) do
    body = %{
      input: query,
      includedPrimaryTypes: ["locality"],
      sessionToken: session_token
    }

    case Req.post(@autocomplete_url,
           json: body,
           headers: [
             {"X-Goog-Api-Key", api_key()},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: %{"suggestions" => suggestions}}} ->
        {:ok, parse_suggestions(suggestions)}

      {:ok, %{status: 200, body: _}} ->
        {:ok, []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  def autocomplete(_, _), do: {:ok, []}

  @impl true
  def place_details(place_id, session_token) when is_binary(place_id) do
    url = "https://places.googleapis.com/v1/places/#{place_id}"

    case Req.get(url,
           headers: [
             {"X-Goog-Api-Key", api_key()},
             {"X-Goog-FieldMask", "location"}
           ],
           params: [sessionToken: session_token]
         ) do
      {:ok, %{status: 200, body: %{"location" => %{"latitude" => lat, "longitude" => lng}}}} ->
        {:ok, %{latitude: lat, longitude: lng}}

      {:ok, %{status: 200, body: _}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_suggestions(suggestions) when is_list(suggestions) do
    suggestions
    |> Enum.filter(&match?(%{"placePrediction" => _}, &1))
    |> Enum.map(fn %{"placePrediction" => prediction} ->
      %{
        place_id: get_in(prediction, ["placeId"]),
        display_text: get_in(prediction, ["text", "text"]) || "",
        main_text: get_in(prediction, ["structuredFormat", "mainText", "text"]) || "",
        secondary_text: get_in(prediction, ["structuredFormat", "secondaryText", "text"]) || ""
      }
    end)
  end

  defp parse_suggestions(_), do: []

  defp api_key do
    Application.get_env(:huddlz, :google_maps)[:api_key]
  end
end
