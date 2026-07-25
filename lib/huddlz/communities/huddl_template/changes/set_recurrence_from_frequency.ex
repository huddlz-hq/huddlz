defmodule Huddlz.Communities.HuddlTemplate.Changes.SetRecurrenceFromFrequency do
  @moduledoc """
  Translates the form-facing cadence choice into the template's explicit
  interval and unit.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :frequency) do
      :weekly ->
        set_recurrence(changeset, 1, :week)

      :every_two_weeks ->
        set_recurrence(changeset, 2, :week)

      :monthly ->
        set_recurrence(changeset, 1, :month)

      nil ->
        changeset
    end
  end

  defp set_recurrence(changeset, interval, unit) do
    changeset
    |> Ash.Changeset.change_attribute(:interval, interval)
    |> Ash.Changeset.change_attribute(:unit, unit)
  end
end
