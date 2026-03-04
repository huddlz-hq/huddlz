defmodule Huddlz.Communities.Huddl.Changes.AddHuddlTemplate do
  @moduledoc """
  Create a huddl template if huddl is recurring
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      case Ash.Changeset.get_argument(changeset, :is_recurring) do
        true ->
          repeat_until = Ash.Changeset.get_argument(changeset, :repeat_until)
          frequency = Ash.Changeset.get_argument(changeset, :frequency)

          huddl_template =
            HuddlTemplate
            |> Ash.Changeset.for_create(:create, %{
              repeat_until: repeat_until,
              frequency: frequency
            })
            |> Ash.create!(authorize?: false)

          huddl =
            huddl
            |> Ash.Changeset.for_update(:update, %{huddl_template_id: huddl_template.id})
            |> Ash.update!(authorize?: false)

          RecurrenceHelper.generate_huddlz_from_template(huddl_template, huddl)

          {:ok, huddl}

        _ ->
          {:ok, huddl}
      end
    end)
  end
end
