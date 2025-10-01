defmodule Huddlz.Communities.Huddl.Validations.FutureDateValidation do
  @moduledoc """
  Validates that the date argument is in the future for create actions.
  """

  use Ash.Resource.Validation
  alias Ash.Error.Changes.InvalidArgument

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
         {:ok, starts_at} <- DateTime.new(date, start_time, "Etc/UTC") do
      validate_future_datetime(starts_at)
    else
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
