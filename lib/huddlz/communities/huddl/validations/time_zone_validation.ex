defmodule Huddlz.Communities.Huddl.Validations.TimeZoneValidation do
  @moduledoc """
  Ensures a persisted huddl time zone is a recognized IANA name.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    time_zone = Ash.Changeset.get_attribute(changeset, :time_zone)

    if is_nil(time_zone) or Huddlz.TimeZone.valid?(time_zone) do
      :ok
    else
      {:error,
       InvalidAttribute.exception(
         field: :time_zone,
         value: time_zone,
         message: "must be a valid IANA time zone"
       )}
    end
  end
end
