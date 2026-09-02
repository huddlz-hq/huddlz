defmodule Huddlz.Communities.Huddl.Changes.DefaultTimeZoneFromGroup do
  @moduledoc """
  Uses the group's authoritative time zone when a huddl does not have a
  physical-location time zone yet. Virtual huddlz always use this value.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Group

  @impl true
  def change(changeset, _opts, _context) do
    if derive_time_zone?(changeset) do
      put_authoritative_time_zone(changeset)
    else
      changeset
    end
  end

  defp derive_time_zone?(%{action_type: :create} = changeset) do
    Ash.Changeset.get_attribute(changeset, :event_type) == :virtual
  end

  defp derive_time_zone?(%{action_type: :update} = changeset) do
    Ash.Changeset.get_attribute(changeset, :event_type) == :virtual
  end

  defp derive_time_zone?(_changeset), do: false

  defp put_authoritative_time_zone(changeset) do
    cond do
      preserve_existing_virtual_zone?(changeset) ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, changeset.data.time_zone)

      template_id = Ash.Changeset.get_attribute(changeset, :huddl_template_id) ->
        put_template_time_zone(changeset, template_id)

      true ->
        put_group_time_zone(changeset)
    end
  end

  defp preserve_existing_virtual_zone?(%{action_type: :update} = changeset) do
    not Ash.Changeset.changing_attribute?(changeset, :event_type)
  end

  defp preserve_existing_virtual_zone?(_changeset), do: false

  defp put_group_time_zone(changeset) do
    case group_for(changeset) do
      %{time_zone: time_zone} when is_binary(time_zone) ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)

      _group ->
        Ash.Changeset.add_error(changeset,
          field: :group_id,
          message: "group time zone could not be loaded"
        )
    end
  end

  defp put_template_time_zone(changeset, template_id) do
    case Ash.get(Huddlz.Communities.HuddlTemplate, template_id, authorize?: false) do
      {:ok, %{time_zone: time_zone}} when is_binary(time_zone) ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)

      _error ->
        Ash.Changeset.add_error(changeset,
          field: :huddl_template_id,
          message: "recurring schedule time zone could not be loaded"
        )
    end
  end

  defp group_for(changeset) do
    group_id = Ash.Changeset.get_attribute(changeset, :group_id)

    case Ash.get(Group, group_id, authorize?: false) do
      {:ok, group} -> group
      _error -> nil
    end
  end
end
