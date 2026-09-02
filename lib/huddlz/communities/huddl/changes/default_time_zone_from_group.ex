defmodule Huddlz.Communities.Huddl.Changes.DefaultTimeZoneFromGroup do
  @moduledoc """
  Uses the Group time zone as the authoritative zone for new virtual huddlz.

  Venue-aware scheduling replaces this value for physical and hybrid huddlz.
  Generated recurring instances retain their template's authoritative zone,
  and changing an existing huddl to virtual adopts the current Group zone.
  Caller input is never authoritative.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    if derive_time_zone?(changeset) do
      default_time_zone(changeset, context)
    else
      changeset
    end
  end

  defp derive_time_zone?(%{action_type: :create}), do: true

  defp derive_time_zone?(%{action_type: :update} = changeset) do
    Ash.Changeset.changing_attribute?(changeset, :event_type) and
      Ash.Changeset.get_attribute(changeset, :event_type) == :virtual
  end

  defp derive_time_zone?(_changeset), do: false

  defp default_time_zone(changeset, context) do
    case Ash.Changeset.get_attribute(changeset, :huddl_template_id) do
      nil -> default_from_group(changeset, context)
      template_id -> default_from_template(template_id, changeset)
    end
  end

  defp default_from_template(template_id, changeset) do
    case Ash.get(Huddlz.Communities.HuddlTemplate, template_id, authorize?: false) do
      {:ok, %Huddlz.Communities.HuddlTemplate{} = template} ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, template.time_zone)

      _error ->
        Ash.Changeset.add_error(changeset,
          field: :huddl_template_id,
          message: "Recurring schedule time zone could not be loaded"
        )
    end
  end

  defp default_from_group(changeset, context) do
    changeset
    |> Ash.Changeset.get_attribute(:group_id)
    |> default_from_group(changeset, context)
  end

  defp default_from_group(nil, changeset, _context), do: changeset

  defp default_from_group(group_id, changeset, _context) do
    case Ash.get(Huddlz.Communities.Group, group_id, authorize?: false) do
      {:ok, %Huddlz.Communities.Group{} = group} ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, group.time_zone)

      _error ->
        Ash.Changeset.add_error(changeset,
          field: :group_id,
          message: "Group time zone could not be loaded"
        )
    end
  end
end
