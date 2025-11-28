defmodule Huddlz.Accounts.ProfilePicture.Checks.IsOwnPicture do
  @moduledoc """
  Check that verifies the user_id being set matches the actor's id.
  Used for create actions where we can't use expression-based filters.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "user_id matches actor's id"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: changeset}, _opts) do
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)
    user_id == actor.id
  end
end
