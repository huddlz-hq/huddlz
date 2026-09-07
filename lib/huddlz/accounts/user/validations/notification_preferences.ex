defmodule Huddlz.Accounts.User.Validations.NotificationPreferences do
  @moduledoc false
  use Ash.Resource.Validation

  alias Huddlz.Notifications.Triggers

  @impl true
  def validate(changeset, _opts, _context) do
    known_keys = Enum.map(Map.keys(Triggers.all()), &Triggers.preference_key/1)
    preferences = Ash.Changeset.get_argument(changeset, :preferences)

    if Enum.all?(preferences, fn {key, value} -> key in known_keys and is_boolean(value) end) do
      :ok
    else
      {:error,
       field: :preferences,
       message: "must contain only known notification preference keys with boolean values"}
    end
  end
end
