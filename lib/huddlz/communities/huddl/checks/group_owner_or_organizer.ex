defmodule Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer do
  @moduledoc """
  Check if the actor is the owner or an organizer of the group.
  Used for create actions where expression policies can't traverse relationships.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.{Group, GroupMember}
  require Ash.Query

  def describe(_opts) do
    "actor is the group owner or an organizer"
  end

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    group_id =
      Ash.Changeset.get_argument(changeset, :group_id) ||
        Ash.Changeset.get_attribute(changeset, :group_id)

    check_authorization(actor, group_id)
  end

  def match?(_actor, _context, _opts), do: false

  defp check_authorization(_actor, nil), do: false

  defp check_authorization(actor, group_id) do
    case Ash.get(Group, group_id, authorize?: false) do
      {:ok, group} when group.owner_id == actor.id ->
        true

      {:ok, group} ->
        GroupMember
        |> Ash.Query.filter(group_id: group.id, user_id: actor.id, role: :organizer)
        |> Ash.exists?(authorize?: false)

      _ ->
        false
    end
  end
end
