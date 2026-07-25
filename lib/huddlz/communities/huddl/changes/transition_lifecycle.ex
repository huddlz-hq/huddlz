defmodule Huddlz.Communities.Huddl.Changes.TransitionLifecycle do
  @moduledoc """
  Serializes publish and cancellation transitions on the huddl row.

  Repeating the transition is a successful no-op. The context flag is consumed
  by notification changes so retries and concurrent submissions fan out once.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :to) do
      {:ok, target} when target in [:published, :cancelled] -> {:ok, opts}
      _ -> {:error, "expected :to to be :published or :cancelled"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    target = Keyword.fetch!(opts, :to)
    Ash.Changeset.before_action(changeset, &transition(&1, target))
  end

  defp transition(changeset, target) do
    current = lock_huddl!(changeset.data.id)
    apply_transition(changeset, current.lifecycle_state, target)
  end

  defp apply_transition(changeset, :draft, :published) do
    changeset
    |> Ash.Changeset.force_change_attribute(:lifecycle_state, :published)
    |> Ash.Changeset.force_change_attribute(:published_at, DateTime.utc_now())
    |> Ash.Changeset.put_context(:lifecycle_transition, :published)
  end

  defp apply_transition(changeset, :published, :published), do: changeset

  defp apply_transition(changeset, :published, :cancelled) do
    changeset
    |> Ash.Changeset.force_change_attribute(:lifecycle_state, :cancelled)
    |> Ash.Changeset.force_change_attribute(:cancelled_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(
      :cancellation_reason,
      normalize_reason(Ash.Changeset.get_argument(changeset, :cancellation_reason))
    )
    |> Ash.Changeset.put_context(:lifecycle_transition, :cancelled)
  end

  defp apply_transition(changeset, :cancelled, :cancelled), do: changeset

  defp apply_transition(changeset, :cancelled, :published) do
    Ash.Changeset.add_error(changeset, "A cancelled huddl cannot be published.")
  end

  defp apply_transition(changeset, :draft, :cancelled) do
    Ash.Changeset.add_error(changeset, "Delete an unpublished draft instead of cancelling it.")
  end

  defp lock_huddl!(huddl_id) do
    Huddl
    |> Ash.Query.for_read(:get_for_lifecycle_transition, %{id: huddl_id})
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp normalize_reason(reason) when is_binary(reason) do
    case String.trim(reason) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_reason(_reason), do: nil
end
