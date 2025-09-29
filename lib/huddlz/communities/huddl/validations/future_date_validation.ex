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
    # Only validate on create
    if changeset.action.name == :create do
      date = Ash.Changeset.get_argument(changeset, :date)
      start_time = Ash.Changeset.get_argument(changeset, :start_time)

      # Only validate if we have both date and time
      if date && start_time do
        case DateTime.new(date, start_time, "Etc/UTC") do
          {:ok, starts_at} ->
            if DateTime.compare(starts_at, DateTime.utc_now()) == :lt do
              {:error,
               InvalidArgument.exception(
                 field: :date,
                 message: "must be in the future"
               )}
            else
              :ok
            end

          _ ->
            :ok
        end
      else
        :ok
      end
    else
      :ok
    end
  end
end
