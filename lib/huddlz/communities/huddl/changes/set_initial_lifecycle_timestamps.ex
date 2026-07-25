defmodule Huddlz.Communities.Huddl.Changes.SetInitialLifecycleTimestamps do
  @moduledoc """
  Records when a huddl is created already published. Drafts receive their
  publication timestamp only when the explicit publish action succeeds.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :lifecycle_state) do
      :published ->
        Ash.Changeset.force_change_attribute(changeset, :published_at, DateTime.utc_now())

      _state ->
        changeset
    end
  end
end
