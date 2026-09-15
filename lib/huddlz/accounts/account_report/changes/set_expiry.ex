defmodule Huddlz.Accounts.AccountReport.Changes.SetExpiry do
  @moduledoc """
  A report is shown to administrators for two years from the moment it
  was sent, independent of what happens to the account.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(changeset, :expires_at, expires_at())
  end

  @doc "Two years from now."
  def expires_at(now \\ DateTime.utc_now()), do: DateTime.shift(now, year: 2)
end
