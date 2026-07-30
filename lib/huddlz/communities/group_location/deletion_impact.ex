defmodule Huddlz.Communities.GroupLocation.DeletionImpact do
  @moduledoc """
  Finds current and upcoming huddlz linked to a saved location.

  Huddlz snapshot venue text and coordinates while retaining the saved
  location identifier. Deleting a location nils that identifier for historical
  huddlz without changing their displayable venue details.
  """

  require Ash.Query

  alias Huddlz.Communities.Huddl

  def active_references(location) do
    now = DateTime.utc_now()

    Huddl
    |> Ash.Query.filter(
      group_id == ^location.group_id and
        group_location_id == ^location.id and
        ends_at >= ^now
    )
    |> Ash.Query.select([:id])
    |> Ash.read(authorize?: false)
  end

  def error_message(reference_count) do
    huddl_label = if reference_count == 1, do: "huddl", else: "huddlz"
    move_instruction = if reference_count == 1, do: "Move it", else: "Move those huddlz"

    "This location is used by #{reference_count} current or upcoming #{huddl_label}. " <>
      "#{move_instruction} to another venue before deleting it."
  end
end
