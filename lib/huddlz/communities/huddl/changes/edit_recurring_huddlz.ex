defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz do
  @moduledoc """
  Edit a huddl series
  """
  use Ash.Resource.Change
  require Ash.Query

  alias Huddlz.Communities.Huddl
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

        delete_future_instances(huddl)
        RecurrenceHelper.generate_huddlz_from_template(huddl_template, huddl)

        {:ok, huddl}
    end
  end

  # Reads every later instance in the series through the dedicated,
  # visibility-free :siblings_in_series action so a private series is cleared
  # in full. The previous bare `Ash.read!()` ran FilterByVisibility as an
  # anonymous actor, found 0 private instances, deleted none, and then
  # regenerated — duplicating the series and double-booking reminders.
  defp delete_future_instances(huddl) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: huddl.huddl_template_id,
      starting_after: huddl.starts_at
    })
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))
  end
end
