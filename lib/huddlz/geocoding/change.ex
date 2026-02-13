defmodule Huddlz.Geocoding.Change do
  @moduledoc """
  Shared geocoding change logic for Ash resources.
  Geocodes a location attribute to latitude/longitude on create/update.
  """

  require Logger

  def geocode_if_changed(changeset, location_attribute) do
    if Ash.Changeset.changing_attribute?(changeset, location_attribute) do
      changeset
      |> Ash.Changeset.get_attribute(location_attribute)
      |> geocode_and_apply(changeset)
    else
      changeset
    end
  end

  defp geocode_and_apply(nil, changeset), do: set_coordinates(changeset, nil, nil)

  defp geocode_and_apply(location, changeset) do
    case Huddlz.Geocoding.geocode(location) do
      {:ok, %{latitude: lat, longitude: lng}} ->
        set_coordinates(changeset, lat, lng)

      {:error, reason} ->
        Logger.warning("Geocoding failed for #{inspect(location)}: #{inspect(reason)}")
        set_coordinates(changeset, nil, nil)
    end
  end

  defp set_coordinates(changeset, lat, lng) do
    changeset
    |> Ash.Changeset.force_change_attribute(:latitude, lat)
    |> Ash.Changeset.force_change_attribute(:longitude, lng)
  end
end
