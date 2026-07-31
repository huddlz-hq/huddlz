defmodule Huddlz.Communities.Huddl.Changes.TransitionLifecycle do
  @moduledoc """
  Serializes publish, cancellation, and completion transitions on the huddl row.

  Repeating the transition is a successful no-op. The context flag is consumed
  by notification changes so retries and concurrent submissions fan out once.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :to) do
      {:ok, target} when target in [:published, :cancelled, :completed] -> {:ok, opts}
      _ -> {:error, "expected :to to be :published, :cancelled, or :completed"}
    end
  end

  @impl true
  def change(changeset, opts, context) do
    target = Keyword.fetch!(opts, :to)
    actor_id = context.actor && context.actor.id
    Ash.Changeset.before_action(changeset, &transition(&1, target, actor_id))
  end

  defp transition(changeset, target, actor_id) do
    current = lock_huddl!(changeset.data.id)
    apply_transition(changeset, current, target, actor_id)
  end

  defp apply_transition(changeset, %{lifecycle_state: :draft}, :published, actor_id) do
    changeset
    |> Ash.Changeset.force_change_attribute(:lifecycle_state, :published)
    |> Ash.Changeset.force_change_attribute(:published_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:published_by_id, actor_id)
    |> Ash.Changeset.put_context(:lifecycle_transition, :published)
  end

  defp apply_transition(
         changeset,
         %{lifecycle_state: :published} = current,
         :published,
         _actor_id
       ),
       do: reflect_current_lifecycle(changeset, current)

  defp apply_transition(changeset, %{lifecycle_state: :published}, :cancelled, actor_id) do
    changeset
    |> Ash.Changeset.force_change_attribute(:lifecycle_state, :cancelled)
    |> Ash.Changeset.force_change_attribute(:cancelled_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:cancelled_by_id, actor_id)
    |> Ash.Changeset.force_change_attribute(
      :cancellation_reason,
      normalize_reason(Ash.Changeset.get_argument(changeset, :cancellation_reason))
    )
    |> Ash.Changeset.put_context(:lifecycle_transition, :cancelled)
  end

  defp apply_transition(
         changeset,
         %{lifecycle_state: :cancelled} = current,
         :cancelled,
         _actor_id
       ),
       do: reflect_current_lifecycle(changeset, current)

  defp apply_transition(changeset, %{lifecycle_state: :published} = huddl, :completed, _actor_id) do
    complete_after_end(changeset, huddl.ends_at)
  end

  defp apply_transition(
         changeset,
         %{lifecycle_state: :completed} = current,
         :completed,
         _actor_id
       ),
       do: reflect_current_lifecycle(changeset, current)

  defp apply_transition(changeset, %{lifecycle_state: :cancelled}, :published, _actor_id) do
    Ash.Changeset.add_error(changeset, "A cancelled huddl cannot be published.")
  end

  defp apply_transition(changeset, %{lifecycle_state: :draft}, :cancelled, _actor_id) do
    Ash.Changeset.add_error(changeset, "Delete an unpublished draft instead of cancelling it.")
  end

  defp apply_transition(changeset, %{lifecycle_state: :completed}, :published, _actor_id) do
    Ash.Changeset.add_error(changeset, "A completed huddl cannot be published.")
  end

  defp apply_transition(changeset, %{lifecycle_state: :completed}, :cancelled, _actor_id) do
    Ash.Changeset.add_error(changeset, "A completed huddl cannot be cancelled.")
  end

  defp apply_transition(changeset, %{lifecycle_state: state}, :completed, _actor_id)
       when state in [:draft, :cancelled] do
    Ash.Changeset.add_error(changeset, "Only a published huddl can be completed.")
  end

  defp complete_after_end(changeset, ends_at) do
    case DateTime.compare(ends_at, DateTime.utc_now()) do
      comparison when comparison in [:lt, :eq] ->
        changeset
        |> Ash.Changeset.force_change_attribute(:lifecycle_state, :completed)
        |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
        |> Ash.Changeset.put_context(:lifecycle_transition, :completed)

      :gt ->
        Ash.Changeset.add_error(changeset, "A huddl cannot be completed before it ends.")
    end
  end

  defp reflect_current_lifecycle(changeset, current) do
    Enum.reduce(
      [
        :lifecycle_state,
        :published_at,
        :published_by_id,
        :cancelled_at,
        :cancelled_by_id,
        :completed_at,
        :cancellation_reason
      ],
      changeset,
      fn attribute, changeset ->
        Ash.Changeset.force_change_attribute(changeset, attribute, Map.fetch!(current, attribute))
      end
    )
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
