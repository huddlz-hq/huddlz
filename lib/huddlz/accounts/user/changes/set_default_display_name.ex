defmodule Huddlz.Accounts.User.Changes.SetDefaultDisplayName do
  @moduledoc """
  Automatically generates a random display name for new users if no display name is provided.
  Only runs on create actions during actual submission (not during validation).
  """
  use Ash.Resource.Change

  alias Huddlz.Accounts.DisplayNameGenerator

  @impl true
  def change(changeset, _opts, _context) do
    # Generate display name only during actual submission
    # Use before_action to ensure it runs at submission time, not during validation
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      display_name = Ash.Changeset.get_attribute(changeset, :display_name)

      if changeset.action_type == :create and (is_nil(display_name) or display_name == "") do
        new_display_name = DisplayNameGenerator.generate()
        Ash.Changeset.change_attribute(changeset, :display_name, new_display_name)
      else
        changeset
      end
    end)
  end
end
