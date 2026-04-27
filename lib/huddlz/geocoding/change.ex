defmodule Huddlz.Geocoding.Change do
  @moduledoc """
  Shared geocoding change logic for Ash resources.
  Geocodes a location attribute to latitude/longitude on create/update.
  """

  require Logger

  def geocode_if_changed(changeset, location_attribute) do
    cond do
      provided_coordinates?(changeset) ->
        changeset

      not Ash.Changeset.changing_attribute?(changeset, location_attribute) ->
        changeset

      true ->
        changeset
        |> Ash.Changeset.get_attribute(location_attribute)
        |> geocode_and_apply(changeset)
    end
  end

  defp provided_coordinates?(changeset) do
    lat = Ash.Changeset.get_argument(changeset, :provided_latitude)
    lng = Ash.Changeset.get_argument(changeset, :provided_longitude)

    is_number(lat) and is_number(lng)
  end

  defp geocode_and_apply(nil, changeset), do: set_coordinates(changeset, nil, nil)

  defp geocode_and_apply(location, changeset) do
    case Huddlz.Geocoding.geocode(location) do
      {:ok, %{latitude: lat, longitude: lng}} ->
        set_coordinates(changeset, lat, lng)

      {:error, reason} ->
        log_geocoding_failure(location, reason)
        set_coordinates(changeset, nil, nil)
    end
  end

  # The default test stub always returns {:error, :not_found}; warning on
  # every test create would just be log spam.
  defp log_geocoding_failure(location, reason) do
    if Application.get_env(:huddlz, :env) != :test do
      Logger.warning("Geocoding failed for #{inspect(location)}: #{inspect(reason)}")
    end
  end

  defp set_coordinates(changeset, lat, lng) do
    changeset
    |> Ash.Changeset.force_change_attribute(:latitude, lat)
    |> Ash.Changeset.force_change_attribute(:longitude, lng)
  end
end
