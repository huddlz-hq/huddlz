defmodule Huddlz.Communities.Huddl.Changes.AddCreatorAsAttendee do
  @moduledoc false

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.HuddlAttendee

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      with {:ok, actor} <- creator_actor(context.actor, huddl.creator_id),
           {:ok, _attendance} <-
             HuddlAttendee
             |> Ash.Changeset.for_create(
               :rsvp,
               %{huddl_id: huddl.id, user_id: huddl.creator_id},
               actor: actor
             )
             |> Ash.create(authorize?: false) do
        {:ok, huddl}
      end
    end)
  end

  defp creator_actor(%{id: _id} = actor, _creator_id), do: {:ok, actor}
  defp creator_actor(_actor, creator_id), do: Ash.get(User, creator_id, authorize?: false)
end
