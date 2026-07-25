defmodule Huddlz.Communities.GroupLocation.DeletionImpact do
  @moduledoc """
  Finds current and upcoming huddlz whose copied venue address matches a
  saved location.

  Huddlz intentionally snapshot venue text and coordinates when they are
  scheduled. That keeps historical venue details intact after an address-book
  entry is removed. This query identifies the snapshots that still represent
  active commitments and must therefore block deletion.
  """

  require Ash.Query

  alias Huddlz.Communities.Huddl

  def active_references(location) do
    now = DateTime.utc_now()

    Huddl
    |> Ash.Query.filter(
      group_id == ^location.group_id and
        physical_location == ^location.address and
        ends_at >= ^now
    )
    |> Ash.Query.select([:title, :starts_at, :huddl_template_id])
    |> Ash.read(authorize?: false)
  end

  def error_message(reference_count) do
    huddl_label = if reference_count == 1, do: "huddl", else: "huddlz"
    move_instruction = if reference_count == 1, do: "Move it", else: "Move those huddlz"

    "This location is used by #{reference_count} upcoming #{huddl_label}. " <>
      "#{move_instruction} to another venue before deleting it."
  end
end
