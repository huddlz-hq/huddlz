defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz do
  @moduledoc """
  Propagates an "edit all" to the rest of a recurring series.

  Updates every later instance **in place** so subscribers keep their RSVPs and
  are notified their event changed (see `RecurrenceHelper.reconcile_future_instances/3`);
  it never deletes-and-recreates occupied occurrences.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.RecurrenceHelper

  def change(changeset, _opts, context) do
    actor = context.actor

    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      if Ash.Changeset.get_argument(changeset, :edit_type) == "all" do
        reconcile_series(changeset, huddl, actor)
      else
        {:ok, huddl}
      end
    end)
  end

  defp reconcile_series(changeset, huddl, actor) do
    repeat_until = Ash.Changeset.get_argument(changeset, :repeat_until)
    frequency = Ash.Changeset.get_argument(changeset, :frequency)

    # The update result doesn't carry loaded relationships, and API/GraphQL
    # callers may not have preloaded the template, so load it here.
    huddl = Ash.load!(huddl, :huddl_template, authorize?: false)

    case huddl.huddl_template do
      nil ->
        # Not part of a series; nothing to reconcile.
        {:ok, huddl}

      huddl_template ->
        {:ok, huddl_template} =
          huddl_template
          |> Ash.Changeset.for_update(:update, %{
            repeat_until: repeat_until,
            frequency: frequency
          })
          |> Ash.update(authorize?: false)

        # Synchronous: "edit all" is a rare organizer action, bounded at the
        # series cap, and immediate consistency is preferable here. The create
        # path defers its fan-out to RegenerateRecurringSeries instead.
        RecurrenceHelper.reconcile_future_instances(huddl, huddl_template, actor)

        {:ok, huddl}
    end
  end
end
