defmodule Huddlz.TimeZone.Validation do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    time_zone = Ash.Changeset.get_attribute(changeset, :time_zone)

    if Huddlz.TimeZone.canonical?(time_zone) do
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
