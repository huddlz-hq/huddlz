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

    {:ok, huddl_template} =
      huddl.huddl_template
      |> Ash.Changeset.for_update(:update, %{
        repeat_until: repeat_until,
        frequency: frequency
      })
      |> Ash.update(authorize?: false)

    Huddl
    |> Ash.Query.filter(starts_at > ^huddl.starts_at)
    |> Ash.Query.filter(huddl_template_id: huddl.huddl_template_id)
    |> Ash.read!()
    |> Enum.each(&Ash.destroy(&1, authorize?: false))

    RecurrenceHelper.generate_huddlz_from_template(huddl_template, huddl)

    {:ok, huddl}
  end
end
