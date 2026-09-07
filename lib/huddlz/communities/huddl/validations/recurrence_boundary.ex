defmodule Huddlz.Communities.Huddl.Validations.RecurrenceBoundary do
  @moduledoc """
  Rejects recurrence end dates before the huddl's local start date.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    with %Date{} = repeat_until <- Ash.Changeset.get_argument(changeset, :repeat_until),
         %DateTime{} = starts_at <- Ash.Changeset.get_attribute(changeset, :starts_at),
         time_zone when is_binary(time_zone) <-
           Ash.Changeset.get_attribute(changeset, :time_zone),
         {:ok, local_start} <- DateTime.shift_zone(starts_at, time_zone) do
      if Date.before?(repeat_until, DateTime.to_date(local_start)) do
        {:error, field: :repeat_until, message: "must be on or after the first huddl date"}
      else
        :ok
      end
    else
      _ -> :ok
    end
  end
end
