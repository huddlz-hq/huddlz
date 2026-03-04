defmodule Huddlz.Communities.Huddl.Changes.DefaultLocationFromGroup do
  @moduledoc """
  Sets virtual huddl coordinates from the parent group's location.
  Runs after GeocodeLocation so it only applies when the huddl has no
  coordinates of its own (virtual huddlz without physical_location).
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Group

  def change(changeset, _opts, _context) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)
    lat = Ash.Changeset.get_attribute(changeset, :latitude)
    lng = Ash.Changeset.get_attribute(changeset, :longitude)

    if event_type == :virtual and is_nil(lat) and is_nil(lng) do
      inherit_group_location(changeset)
    else
      changeset
    end
  end

  defp inherit_group_location(changeset) do
    group = get_group(changeset)

    case group do
      %{latitude: lat, longitude: lng} when not is_nil(lat) and not is_nil(lng) ->
        changeset
        |> Ash.Changeset.force_change_attribute(:latitude, lat)
        |> Ash.Changeset.force_change_attribute(:longitude, lng)

      _ ->
        changeset
    end
  end

  defp get_group(changeset) do
    case changeset.context do
      %{group: group} when not is_nil(group) ->
        group

      _ ->
        group_id = Ash.Changeset.get_attribute(changeset, :group_id)

        case Ash.get(Group, group_id, authorize?: false) do
          {:ok, group} -> group
          _ -> nil
        end
    end
  end
end
