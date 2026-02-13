defmodule Huddlz.Places do
  @moduledoc """
  Places autocomplete behaviour and facade.
  Delegates to the configured adapter (Google Places in production, Mox in test).
  """

  @type suggestion :: %{
          place_id: String.t(),
          display_text: String.t(),
          main_text: String.t(),
          secondary_text: String.t()
        }

  @type coordinates :: %{latitude: float(), longitude: float()}

  @doc "Autocomplete a location query, returning matching place suggestions."
  @callback autocomplete(query :: String.t(), session_token :: String.t(), opts :: keyword()) ::
              {:ok, [suggestion()]} | {:error, term()}

  @doc "Get coordinates for a place by its place_id."
  @callback place_details(place_id :: String.t(), session_token :: String.t()) ::
              {:ok, coordinates()} | {:error, term()}

  @adapter Application.compile_env(:huddlz, [:places, :adapter], Huddlz.Places.Google)

  def autocomplete(query, session_token, opts \\ []),
    do: @adapter.autocomplete(query, session_token, opts)

  def place_details(place_id, session_token), do: @adapter.place_details(place_id, session_token)

  @spec error_message(atom()) :: String.t()
  def error_message(:not_found), do: "Could not find that location."
  def error_message(_), do: "Location search is currently unavailable."
end
