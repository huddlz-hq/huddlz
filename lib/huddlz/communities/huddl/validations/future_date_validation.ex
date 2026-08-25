defmodule Huddlz.Communities.Huddl.Validations.FutureDateValidation do
  @moduledoc """
  Validates that the date argument is in the future for create actions.
  """

  use Ash.Resource.Validation
  alias Ash.Error.Changes.InvalidArgument
  alias Huddlz.DateTimeFormatting

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def supports(_opts), do: [Ash.Changeset, Ash.ActionInput]

  @impl true
  def describe(_opts) do
    [message: "must be in the future", vars: []]
  end

  @impl true
  def validate(changeset, _opts, _context) do
    with true <- changeset.action.name == :create,
         date when not is_nil(date) <- Ash.Changeset.get_argument(changeset, :date),
         start_time when not is_nil(start_time) <-
           Ash.Changeset.get_argument(changeset, :start_time),
         time_zone <- Ash.Changeset.get_attribute(changeset, :time_zone) || "Etc/UTC",
         {:ok, starts_at} <- DateTimeFormatting.resolve_wall_time(date, start_time, time_zone) do
      validate_future_datetime(starts_at)
    else
      # Anything that isn't a resolvable instant — including a wall time that
      # falls in a spring-forward gap — passes here and is reported by
      # `CalculateDateTimeFromInputs`, which owns that error message. Using the
      # same resolver keeps this validation honest about ambiguous (fall-back)
      # times: it checks the very instant that will be stored.
      _ -> :ok
    end
  end

  defp validate_future_datetime(starts_at) do
    if DateTime.compare(starts_at, DateTime.utc_now()) == :lt do
      {:error,
       InvalidArgument.exception(
         field: :date,
         message: "must be in the future"
       )}
    else
      :ok
    end
  end
end
