defmodule Huddlz.Accounts.User.Changes.SetDefaultDisplayName do
  @moduledoc """
  Automatically generates a random display name for new users if no display name is provided.
  Only runs on create actions (specifically sign_in_with_magic_link which uses upsert).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Check if this is a new user (no id means it's an insert, not an update)
    is_new_user = !changeset.data.id

    if is_new_user and !Ash.Changeset.get_attribute(changeset, :display_name) do
      display_name = generate_random_display_name()
      Ash.Changeset.change_attribute(changeset, :display_name, display_name)
    else
      changeset
    end
  end

  defp generate_random_display_name do
    adjectives = [
      "Happy",
      "Clever",
      "Gentle",
      "Brave",
      "Wise",
      "Cool",
      "Brilliant",
      "Swift",
      "Calm",
      "Daring"
    ]

    nouns = [
      "Dolphin",
      "Tiger",
      "Eagle",
      "Panda",
      "Wolf",
      "Falcon",
      "Bear",
      "Fox",
      "Lion",
      "Hawk"
    ]

    random_number = :rand.uniform(999)

    "#{Enum.random(adjectives)}#{Enum.random(nouns)}#{random_number}"
  end
end
