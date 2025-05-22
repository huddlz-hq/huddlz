defmodule Huddlz.Communities.GroupMember.Checks.VerifiedNonMemberPublicGroup do
  @moduledoc """
  Check if the actor is a verified non-member trying to access a public group.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is a verified non-member accessing a public group"
  end

  @impl true
  def match?(actor, %{subject: %{arguments: %{group_id: group_id}}}, _opts)
      when is_map(actor) and is_binary(group_id) do
    if actor.role == :verified do
      case Ash.get(Huddlz.Communities.Group, group_id, actor: actor) do
        {:ok, group} ->
          if group.is_public do
            # Check if the user is NOT a member of this group
            case Huddlz.Communities.GroupMember
                 |> Ash.Query.filter(group_id == ^group_id and user_id == ^actor.id)
                 |> Ash.read_one(authorize?: false) do
              # Not a member
              {:ok, nil} -> true
              # Is a member or error
              _ -> false
            end
          else
            false
          end

        _ ->
          false
      end
    else
      false
    end
  end

  def match?(_actor, _params, _opts) do
    false
  end
end
