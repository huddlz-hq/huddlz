defmodule Huddlz.TimeZone.Validation do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, opts, _context) do
    attribute = Keyword.get(opts, :attribute, :time_zone)
    time_zone = Ash.Changeset.get_attribute(changeset, attribute)

    if (is_nil(time_zone) and Keyword.get(opts, :allow_nil?, false)) or
         Huddlz.TimeZone.canonical?(time_zone) do
      :ok
    else
      {:error,
       InvalidAttribute.exception(
         field: attribute,
         value: time_zone,
         message: "must be a valid IANA time zone"
       )}
    end
  end
end
