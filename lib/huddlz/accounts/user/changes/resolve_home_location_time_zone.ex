defmodule Huddlz.Accounts.User.Changes.ResolveHomeLocationTimeZone do
  @moduledoc false

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    latitude = Ash.Changeset.get_attribute(changeset, :home_latitude)
    longitude = Ash.Changeset.get_attribute(changeset, :home_longitude)

    case Huddlz.LocationTimeZone.resolve(latitude, longitude) do
      {:ok, time_zone} ->
        Ash.Changeset.force_change_attribute(changeset, :home_time_zone, time_zone)

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset,
          field: :home_time_zone,
          message: "Choose a valid IANA time zone"
        )
    end
  end
end
