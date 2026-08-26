defmodule Huddlz.Test.Helpers.TimeZoneSelection do
  @moduledoc """
  Simulates `HuddlzWeb.Live.TimeZoneSelect` notifying its parent LiveView.

  The picker resolves its own list of common/all zones and only ever tells
  the parent the id the organizer clicked, exactly like
  `HuddlzWeb.Live.LocationAutocomplete` and `HuddlzWeb.Live.SavedLocationPicker`
  — so tests send that message directly rather than driving the dropdown's
  DOM (which, being plain server-rendered markup with no client JS of its
  own, has nothing for `PhoenixTest`'s no-JS driver to click through beyond
  what `render_click`/`render_change` already exercise elsewhere).
  """

  @doc """
  Picks a time zone, mimicking `{:time_zone_selected, id, zone_id}`.
  """
  def select_time_zone(session_or_view, zone_id, opts \\ []) do
    id = Keyword.get(opts, :id, "huddl-time-zone")
    notify(session_or_view, {:time_zone_selected, id, zone_id})
  end

  @doc """
  Clears a time zone pick back to its prompt, mimicking
  `{:time_zone_cleared, id}`.
  """
  def clear_time_zone(session_or_view, opts \\ []) do
    id = Keyword.get(opts, :id, "huddl-time-zone")
    notify(session_or_view, {:time_zone_cleared, id})
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
