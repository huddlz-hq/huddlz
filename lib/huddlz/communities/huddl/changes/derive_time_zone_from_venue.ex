defmodule Huddlz.Communities.Huddl.Changes.DeriveTimeZoneFromVenue do
  @moduledoc """
  Uses the selected saved venue's Location time zone for physical and hybrid huddlz.

  Virtual huddlz retain their organizer-selected Huddl time zone. On updates,
  this change runs before schedule inputs are converted to UTC so venue moves
  preserve the organizer-entered wall-clock start and end.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs

  @physical_types [:in_person, :hybrid]

  @impl true
  def change(changeset, _opts, context) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)
    location_id = Ash.Changeset.get_attribute(changeset, :group_location_id)

    derive_from_location(changeset, event_type, location_id, context)
  end

  defp derive_from_location(changeset, event_type, location_id, context)
       when event_type in @physical_types and not is_nil(location_id) do
    case Huddlz.Communities.get_group_location(location_id, scope: context) do
      {:ok, location} when not is_nil(location) ->
        changeset
        |> preserve_wall_clock_on_venue_move(location.time_zone)
        |> Ash.Changeset.force_change_attribute(:time_zone, location.time_zone)

      {:error, _reason} ->
        venue_not_available(changeset)

      {:ok, nil} ->
        venue_not_available(changeset)
    end
  end

  defp derive_from_location(changeset, _event_type, _location_id, _context), do: changeset

  defp preserve_wall_clock_on_venue_move(changeset, new_time_zone) do
    old_time_zone = Map.get(changeset.data, :time_zone)

    if venue_move_without_schedule_inputs?(changeset) and old_time_zone != new_time_zone do
      Enum.reduce([:starts_at, :ends_at], changeset, fn attribute, changeset ->
        preserve_wall_clock(changeset, attribute, old_time_zone, new_time_zone)
      end)
    else
      changeset
    end
  end

  defp venue_move_without_schedule_inputs?(changeset) do
    changeset.action_type == :update and
      Ash.Changeset.changing_attribute?(changeset, :group_location_id) and
      not complete_schedule_inputs?(changeset)
  end

  defp complete_schedule_inputs?(changeset) do
    Enum.all?([:date, :start_time, :duration_minutes], fn argument ->
      not is_nil(Ash.Changeset.get_argument(changeset, argument))
    end)
  end

  defp preserve_wall_clock(changeset, attribute, old_time_zone, new_time_zone) do
    if Ash.Changeset.changing_attribute?(changeset, attribute) do
      changeset
    else
      datetime = Map.get(changeset.data, attribute)

      case move_wall_clock(datetime, old_time_zone, new_time_zone) do
        {:ok, moved_datetime} ->
          Ash.Changeset.force_change_attribute(changeset, attribute, moved_datetime)

        {:error, reason} ->
          Ash.Changeset.add_error(changeset,
            field: attribute,
            message: "cannot preserve wall-clock time: #{reason}"
          )
      end
    end
  end

  defp move_wall_clock(%DateTime{} = datetime, old_time_zone, new_time_zone) do
    with {:ok, old_local} <- DateTime.shift_zone(datetime, old_time_zone) do
      CalculateDateTimeFromInputs.build_datetime(
        DateTime.to_date(old_local),
        DateTime.to_time(old_local),
        new_time_zone
      )
    end
  end

  defp move_wall_clock(_datetime, _old_time_zone, _new_time_zone), do: {:error, :invalid_datetime}

  defp venue_not_available(changeset) do
    Ash.Changeset.add_error(changeset,
      field: :group_location_id,
      message: "selected venue is not available"
    )
  end
end
