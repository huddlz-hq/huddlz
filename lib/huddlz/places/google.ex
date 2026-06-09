defmodule Huddlz.Places.Google do
  @moduledoc """
  Google Places API (New) implementation for location autocomplete.
  """

  @behaviour Huddlz.Places

  @autocomplete_url "https://places.googleapis.com/v1/places:autocomplete"

  # Autocomplete fires per keystroke from LiveView; cap how long a slow
  # Google response can hold a connection, and don't let Req's default
  # retry-with-backoff multiply that wait.
  @req_options [receive_timeout: :timer.seconds(5), retry: false]

  @impl true
  def autocomplete(query, _session_token, _opts) when is_binary(query) and byte_size(query) < 2 do
    {:ok, []}
  end

  def autocomplete(query, session_token, opts) when is_binary(query) do
    types = Keyword.get(opts, :types, ["locality"])

    body = %{
      input: query,
      sessionToken: session_token
    }

    body = if types != [], do: Map.put(body, :includedPrimaryTypes, types), else: body

    opts =
      [
        json: body,
        redirect: false,
        headers: [
          {"X-Goog-Api-Key", api_key()},
          {"Content-Type", "application/json"}
        ]
      ] ++ @req_options ++ req_test_options()

    case Req.post(@autocomplete_url, opts) do
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

  def autocomplete(_, _, _), do: {:ok, []}

  @impl true
  def place_details(place_id, session_token) when is_binary(place_id) do
    url = "https://places.googleapis.com/v1/places/#{place_id}"

    opts =
      [
        redirect: false,
        headers: [
          {"X-Goog-Api-Key", api_key()},
          {"X-Goog-FieldMask", "location"}
        ],
        params: [sessionToken: session_token]
      ] ++ @req_options ++ req_test_options()

    case Req.get(url, opts) do
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

  # These are direct calls to Google's Places host, which never legitimately
  # redirects. `redirect: false` is set on both requests so the
  # X-Goog-Api-Key header can't be forwarded to another host if a 3xx is ever
  # returned (Req's cross-host credential stripping only covers `authorization`,
  # not arbitrary custom headers).
  defp req_test_options do
    case Application.get_env(:huddlz, :places_req_plug) do
      nil -> []
      plug -> [plug: plug]
    end
  end
end
