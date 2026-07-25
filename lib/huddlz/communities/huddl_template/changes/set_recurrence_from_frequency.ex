defmodule Huddlz.Communities.HuddlTemplate.Changes.SetRecurrenceFromFrequency do
  @moduledoc """
  Translates the form-facing cadence choice into the template's explicit
  interval and unit.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    set_recurrence(changeset, Ash.Changeset.get_argument(changeset, :frequency))
  end

  defp set_recurrence(changeset, :weekly),
    do: Ash.Changeset.change_attribute(changeset, :unit, :week)

  defp set_recurrence(changeset, :every_two_weeks), do: set_recurrence(changeset, 2, :week)
  defp set_recurrence(changeset, :monthly), do: set_recurrence(changeset, 1, :month)
  defp set_recurrence(changeset, nil), do: changeset

  defp set_recurrence(changeset, interval, unit) do
    changeset
    |> Ash.Changeset.change_attribute(:interval, interval)
    |> Ash.Changeset.change_attribute(:unit, unit)
  end
end
