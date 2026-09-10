defmodule Huddlz.Communities.GroupLocation.DeletionImpact do
  @moduledoc """
  Finds current and upcoming huddlz linked to a saved location.

  Huddlz snapshot venue text and coordinates while retaining the saved
  location identifier. Deleting a location nils that identifier for historical
  huddlz without changing their displayable venue details.
  """

  alias Huddlz.Communities

  def active_references(location) do
    Communities.location_deletion_blockers(
      location.group_id,
      location.id,
      authorize?: false
    )
  end

  def error_message(reference_count) do
    huddl_label = if reference_count == 1, do: "huddl", else: "huddlz"
    move_instruction = if reference_count == 1, do: "Move it", else: "Move those huddlz"

    "This location is used by #{reference_count} current or upcoming #{huddl_label}. " <>
      "#{move_instruction} to another venue before deleting it."
  end
end
