defmodule Huddlz.Accounts.User.Validations.DisplayTimeZone do
  @moduledoc """
  Requires Fixed Display time to use a recognized IANA identifier.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    mode = Ash.Changeset.get_attribute(changeset, :display_time_zone_mode)
    time_zone = Ash.Changeset.get_attribute(changeset, :fixed_display_time_zone)

    validate_preference(mode, time_zone)
  end

  defp validate_preference(:automatic, nil), do: :ok
  defp validate_preference(:automatic, time_zone), do: validate_canonical(time_zone)
  defp validate_preference(:fixed, time_zone), do: validate_canonical(time_zone)

  defp validate_canonical(time_zone) do
    if Huddlz.TimeZone.canonical?(time_zone) do
      :ok
    else
      {:error,
       InvalidAttribute.exception(
         field: :fixed_display_time_zone,
         value: time_zone,
         message: "must be a canonical IANA time zone"
       )}
    end
  end
end
