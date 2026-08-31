defmodule Huddlz.Accounts.User.Validations.HomeLocationTimeZone do
  @moduledoc false

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    location = Ash.Changeset.get_attribute(changeset, :home_location)
    time_zone = Ash.Changeset.get_attribute(changeset, :home_time_zone)

    validate_pair(location, time_zone)
  end

  defp validate_pair(nil, nil), do: :ok

  defp validate_pair(location, time_zone) when is_binary(location) and is_binary(time_zone) do
    if Huddlz.TimeZone.canonical?(time_zone) do
      :ok
    else
      invalid_time_zone(time_zone)
    end
  end

  defp validate_pair(_location, time_zone), do: invalid_time_zone(time_zone)

  defp invalid_time_zone(time_zone) do
    {:error, field: :home_time_zone, value: time_zone, message: "Choose a valid IANA time zone"}
  end
end
