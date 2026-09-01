defmodule Huddlz.Communities.Huddl.Changes.DefaultTimeZoneFromGroup do
  @moduledoc """
  Uses the Group time zone when a caller does not provide a huddl time zone.

  Venue-aware scheduling can replace this default before persistence; virtual
  huddlz retain it unless the organizer chooses another canonical zone.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    cond do
      explicit_time_zone?(changeset) -> changeset
      is_binary(Ash.Changeset.get_attribute(changeset, :time_zone)) -> changeset
      true -> default_from_group(changeset, context)
    end
  end

  defp explicit_time_zone?(changeset) do
    Map.has_key?(changeset.params, :time_zone) or Map.has_key?(changeset.params, "time_zone")
  end

  defp default_from_group(changeset, context) do
    changeset
    |> Ash.Changeset.get_attribute(:group_id)
    |> default_from_group(changeset, context)
  end

  defp default_from_group(nil, changeset, _context), do: changeset

  defp default_from_group(group_id, changeset, context) do
    case Huddlz.Communities.get_group(group_id, scope: context) do
      {:ok, group} ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, group.time_zone)

      {:error, _reason} ->
        # Keep an inaccessible Group from turning an authorization failure into
        # an unrelated validation error. The create policy remains authoritative.
        Ash.Changeset.force_change_attribute(
          changeset,
          :time_zone,
          Huddlz.TimeZone.eastern_fallback()
        )
    end
  end
end
