defmodule Huddlz.Communities.GroupLocation.Changes.PreventScheduledDeletion do
  @moduledoc """
  Prevents removal of a saved location while current or upcoming huddlz still
  use its snapshotted venue address.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.GroupLocation.DeletionImpact

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &check_references/1)
  end

  defp check_references(changeset) do
    case DeletionImpact.active_references(changeset.data) do
      {:ok, []} ->
        changeset

      {:ok, references} ->
        Ash.Changeset.add_error(
          changeset,
          message: DeletionImpact.error_message(length(references))
        )

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end
end
