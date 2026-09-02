defmodule Huddlz.Communities.Huddl.Changes.ApplySavedLocation do
  @moduledoc """
  Copies the chosen address book location onto an in-person or hybrid huddl:
  its address, coordinates, and time zone.

  When an existing huddl moves, its wall-clock schedule is preserved in the
  saved location's time zone.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.GroupLocation
  alias Huddlz.TimeZone

  @impl true
  def change(changeset, _opts, _context) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)

    if event_type in [:in_person, :hybrid] do
      set_from_saved_location(changeset)
    else
      changeset
    end
  end

  defp set_from_saved_location(changeset) do
    group_location_id = Ash.Changeset.get_attribute(changeset, :group_location_id)
    group_id = Ash.Changeset.get_attribute(changeset, :group_id)

    apply_saved_location(changeset, group_location_id, group_id)
  end

  defp apply_saved_location(changeset, nil, _group_id), do: changeset

  defp apply_saved_location(changeset, group_location_id, group_id) do
    case Ash.get(GroupLocation, group_location_id, authorize?: false) do
      {:ok, %{group_id: ^group_id, time_zone: time_zone} = location}
      when is_binary(time_zone) ->
        changeset
        |> preserve_wall_clock_on_move(time_zone)
        |> Ash.Changeset.force_change_attribute(:time_zone, time_zone)
        |> Ash.Changeset.force_change_attribute(:physical_location, location.address)
        |> Ash.Changeset.force_change_attribute(:latitude, location.latitude)
        |> Ash.Changeset.force_change_attribute(:longitude, location.longitude)

      {:ok, %GroupLocation{}} ->
        Ash.Changeset.add_error(changeset,
          field: :group_location_id,
          message: "saved location must belong to the huddl's group"
        )

      {:error, _error} ->
        Ash.Changeset.add_error(changeset,
          field: :group_location_id,
          message: "saved location is unavailable"
        )
    end
  end

  defp preserve_wall_clock_on_move(%{action_type: :update} = changeset, new_time_zone) do
    if Ash.Changeset.changing_attribute?(changeset, :group_location_id) and
         not complete_schedule_inputs?(changeset) do
      old_time_zone = Map.get(changeset.data, :time_zone)

      Enum.reduce([:starts_at, :ends_at], changeset, fn attribute, changeset ->
        preserve_wall_clock(changeset, attribute, old_time_zone, new_time_zone)
      end)
    else
      changeset
    end
  end

  defp preserve_wall_clock_on_move(changeset, _new_time_zone), do: changeset

  defp complete_schedule_inputs?(changeset) do
    Enum.all?([:date, :start_time, :duration_minutes], fn argument ->
      not is_nil(Ash.Changeset.get_argument(changeset, argument))
    end)
  end

  defp preserve_wall_clock(changeset, attribute, old_time_zone, new_time_zone) do
    datetime = Map.get(changeset.data, attribute)

    with {:ok, old_local} <- DateTime.shift_zone(datetime, old_time_zone),
         {:ok, moved} <- TimeZone.resolve_local(DateTime.to_naive(old_local), new_time_zone) do
      Ash.Changeset.force_change_attribute(changeset, attribute, moved)
    else
      _error ->
        Ash.Changeset.add_error(changeset,
          field: attribute,
          message: "cannot preserve this wall-clock time in #{new_time_zone}"
        )
    end
  end
end
