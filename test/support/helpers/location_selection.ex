defmodule Huddlz.Test.Helpers.LocationSelection do
  @moduledoc """
  Simulates the location picker components notifying their parent LiveView.

  `select_location/2` mimics `HuddlzWeb.Live.LocationAutocomplete` sending
  `{:location_selected, id, payload}`; `select_saved_location/3` mimics
  `HuddlzWeb.Live.SavedLocationPicker` sending
  `{:saved_location_selected, id, location}`. Both accept a PhoenixTest
  session or a `Phoenix.LiveViewTest` view, wait for the message to be
  processed, and return the session/view for piping.
  """

  @default_payload %{
    place_id: "test_place_id",
    display_text: "Austin, TX, USA",
    main_text: "Austin",
    latitude: 30.27,
    longitude: -97.74
  }

  @doc """
  Selects an autocomplete location. Options other than `:id` override the
  default payload, e.g. `select_location(session, display_text: "Berlin")`.
  """
  def select_location(session_or_view, opts \\ []) do
    {id, payload_overrides} = Keyword.pop(opts, :id, "group-location")
    payload = Map.merge(@default_payload, Map.new(payload_overrides))
    notify(session_or_view, {:location_selected, id, payload})
  end

  @doc """
  Selects a saved `GroupLocation` in the saved-location picker.
  """
  def select_saved_location(session_or_view, location, opts \\ []) do
    id = Keyword.get(opts, :id, "saved-location-picker")
    notify(session_or_view, {:saved_location_selected, id, location})
  end

  defp notify(%{view: view} = session, message) do
    notify(view, message)
    session
  end

  defp notify(view, message) do
    send(view.pid, message)
    Phoenix.LiveViewTest.render(view)
    view
  end
end
