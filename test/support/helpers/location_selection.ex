defmodule Huddlz.Test.Helpers.LocationSelection do
  @moduledoc """
  Simulates the location picker components notifying their parent LiveView.

  Address book selections exercise autocomplete with a stubbed place provider.
  Other `select_location/2` calls mimic `HuddlzWeb.Live.LocationAutocomplete` sending
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
    longitude: -97.74,
    time_zone: "America/Chicago"
  }

  @doc """
  Selects an autocomplete location. Options other than `:id` override the
  default payload, e.g. `select_location(session, display_text: "Berlin")`.
  """
  def select_location(session_or_view, opts \\ []) do
    {id, payload_overrides} = Keyword.pop(opts, :id, "group-location")
    payload = Map.merge(@default_payload, Map.new(payload_overrides))

    case id do
      "modal-address-autocomplete" -> select_address(session_or_view, id, payload)
      _ -> notify(session_or_view, {:location_selected, id, payload})
    end
  end

  @doc """
  Selects a saved `GroupLocation` in the saved-location picker.
  """
  def select_saved_location(session_or_view, location, opts \\ []) do
    id = Keyword.get(opts, :id, "saved-location-picker")
    notify(session_or_view, {:saved_location_selected, id, location})
  end

  defp select_address(%{view: view} = session, id, payload) do
    select_address(view, id, payload)
    session
  end

  defp select_address(view, id, payload) do
    suggestion = Map.take(payload, [:place_id, :display_text, :main_text])
    suggestion = Map.put(suggestion, :secondary_text, "")
    details = Map.take(payload, [:latitude, :longitude, :time_zone])

    Mox.stub(Huddlz.MockPlaces, :autocomplete, fn _, _, _ -> {:ok, [suggestion]} end)
    Mox.stub(Huddlz.MockPlaces, :place_details, fn _, _ -> {:ok, details} end)

    view
    |> Phoenix.LiveViewTest.element("##{id}-input")
    |> Phoenix.LiveViewTest.render_change(%{(id <> "_search") => payload.display_text})

    Phoenix.LiveViewTest.render_async(view)

    view
    |> Phoenix.LiveViewTest.element("##{id} [role=option]")
    |> Phoenix.LiveViewTest.render_click()

    Phoenix.LiveViewTest.render_async(view)
    Phoenix.LiveViewTest.render(view)
    view
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
