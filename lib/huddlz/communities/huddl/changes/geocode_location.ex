defmodule Huddlz.Communities.Huddl.Changes.GeocodeLocation do
  @moduledoc """
  Automatically geocodes the physical_location attribute when it changes,
  storing the resulting coordinates in the coordinates field.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _, _) do
    if Ash.Changeset.changing_attribute?(changeset, :physical_location) do
      case Ash.Changeset.get_attribute(changeset, :physical_location) do
        nil ->
          # Clear coordinates if location is removed
          Ash.Changeset.change_attribute(changeset, :coordinates, nil)
        
        "" ->
          # Clear coordinates if location is empty
          Ash.Changeset.change_attribute(changeset, :coordinates, nil)
        
        location ->
          geocode_and_set_coordinates(changeset, location)
      end
    else
      changeset
    end
  end

  defp geocode_and_set_coordinates(changeset, location) do
    case Huddlz.Geocoding.geocode(location) do
      {:ok, %{lat: lat, lng: lng}} ->
        point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
        changeset
        |> Ash.Changeset.change_attribute(:coordinates, point)
        |> Ash.Changeset.put_context(:geocoding_status, :success)
      
      {:error, reason} ->
        # Don't fail the changeset, but track the error for optional display
        changeset
        |> Ash.Changeset.put_context(:geocoding_status, :failed)
        |> Ash.Changeset.put_context(:geocoding_error, reason)
    end
  end
end