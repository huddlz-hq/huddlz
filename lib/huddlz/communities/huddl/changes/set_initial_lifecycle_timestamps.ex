defmodule Huddlz.Communities.Huddl.Changes.SetInitialLifecycleTimestamps do
  @moduledoc """
  Records when a huddl is created already published. Drafts receive their
  publication timestamp only when the explicit publish action succeeds.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.get_attribute(changeset, :lifecycle_state) do
      :published ->
        changeset
        |> Ash.Changeset.force_change_attribute(:published_at, DateTime.utc_now())
        |> set_published_by(context.actor)

      _state ->
        changeset
    end
  end

  defp set_published_by(changeset, %{id: actor_id}) do
    Ash.Changeset.force_change_attribute(changeset, :published_by_id, actor_id)
  end

  defp set_published_by(changeset, _actor), do: changeset
end
