defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz do
  @moduledoc """
  Edit a huddl series
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.RecurrenceHelper

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      if Ash.Changeset.get_argument(changeset, :edit_type) == "all" do
        regenerate_series(changeset, huddl)
      else
        {:ok, huddl}
      end
    end)
  end

  defp regenerate_series(changeset, huddl) do
    repeat_until = Ash.Changeset.get_argument(changeset, :repeat_until)
    frequency = Ash.Changeset.get_argument(changeset, :frequency)

    # The update result doesn't carry loaded relationships, and API/GraphQL
    # callers may not have preloaded the template, so load it here.
    huddl = Ash.load!(huddl, :huddl_template, authorize?: false)

    case huddl.huddl_template do
      nil ->
        # Not part of a series; nothing to regenerate.
        {:ok, huddl}

      huddl_template ->
        {:ok, huddl_template} =
          huddl_template
          |> Ash.Changeset.for_update(:update, %{
            repeat_until: repeat_until,
            frequency: frequency
          })
          |> Ash.update(authorize?: false)

        # Regenerate synchronously: "edit all" is a rare organizer action, and
        # keeping it inline preserves immediate consistency (the create path
        # defers the same fan-out to RegenerateRecurringSeries instead).
        RecurrenceHelper.regenerate_series(huddl, huddl_template)

        {:ok, huddl}
    end
  end
end
