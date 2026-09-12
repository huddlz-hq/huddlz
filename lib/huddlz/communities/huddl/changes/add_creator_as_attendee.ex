defmodule Huddlz.Communities.Huddl.Changes.AddCreatorAsAttendee do
  @moduledoc false
  use Ash.Resource.Change

  alias Huddlz.Communities.HuddlAttendee

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn cs, huddl ->
      with {:ok, _attendance} <-
             HuddlAttendee
             |> Ash.Changeset.for_create(
               :rsvp,
               %{huddl_id: huddl.id, user_id: huddl.creator_id},
               Huddlz.Audit.nested_opts(cs, %{automatic?: true})
             )
             |> Ash.create(authorize?: false) do
        {:ok, huddl}
      end
    end)
  end
end
