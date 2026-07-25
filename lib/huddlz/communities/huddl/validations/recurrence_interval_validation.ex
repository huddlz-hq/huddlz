defmodule Huddlz.Communities.Huddl.Validations.RecurrenceIntervalValidation do
  @moduledoc """
  Requires an explicit interval when a weekly series is created or edited.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    frequency = Ash.Changeset.get_argument(changeset, :frequency)
    interval = Ash.Changeset.get_argument(changeset, :recurrence_interval)

    if weekly_series_change?(changeset, frequency) and is_nil(interval) and
         recurrence_interval_missing?(changeset) do
      {:error,
       field: :recurrence_interval, message: "Choose how many weeks apart this huddl repeats."}
    else
      :ok
    end
  end

  defp weekly_series_change?(changeset, frequency) when frequency in ["weekly", :weekly] do
    Ash.Changeset.get_argument(changeset, :is_recurring) == true or
      Ash.Changeset.get_argument(changeset, :edit_type) == "all"
  end

  defp weekly_series_change?(_changeset, _frequency), do: false

  defp recurrence_interval_missing?(changeset) do
    changeset.params
    |> Map.get(:recurrence_interval, Map.get(changeset.params, "recurrence_interval"))
    |> then(&(&1 in [nil, ""]))
  end
end
