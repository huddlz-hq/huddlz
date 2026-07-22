defmodule Huddlz.Places.Development do
  @moduledoc """
  Development adapter that uses Google Places when an API key is configured
  and falls back to preset locations otherwise.
  """

  @behaviour Huddlz.Places

  @impl true
  def autocomplete(query, session_token, opts) do
    adapter().autocomplete(query, session_token, opts)
  end

  @impl true
  def place_details(place_id, session_token) do
    adapter().place_details(place_id, session_token)
  end

  defp adapter do
    case Application.get_env(:huddlz, :google_maps, [])[:api_key] do
      api_key when is_binary(api_key) and api_key != "" -> Huddlz.Places.Google
      _ -> Huddlz.Places.DevStub
    end
  end
end
