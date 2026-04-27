defmodule Huddlz.Communities.GroupMember.Actions.RemoveMemberByIds do
  @moduledoc """
  Generic-action implementation for the JSON:API `route :delete` route on
  GroupMember. JSON:API's `route :delete` requires a generic action — the
  arg-based `:remove_member` destroy can't be exposed under that helper
  directly.

  Looks up the membership by `(group_id, user_id)` with policies bypassed
  (the destroy itself is the auth gate), then runs the existing
  `:remove_member` destroy with the actor so the GroupOwner policy applies.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  @impl true
  def run(input, _opts, %{actor: actor}) do
    %{group_id: group_id, user_id: user_id} = input.arguments

    case GroupMember
         |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} ->
        {:error, "Membership not found"}

      {:ok, %GroupMember{} = found} ->
        found
        |> Ash.Changeset.for_destroy(
          :remove_member,
          %{group_id: group_id, user_id: user_id},
          actor: actor
        )
        |> Ash.destroy(return_destroyed?: true)

      {:error, _} = err ->
        err
    end
  end
end
