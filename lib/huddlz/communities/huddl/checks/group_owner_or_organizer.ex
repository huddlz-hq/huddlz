defmodule Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer do
  @moduledoc """
  Check if the actor is the owner or an organizer of the group for the huddl.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.{Group, GroupMember}
  require Ash.Query

  def describe(_opts) do
    "actor is the group owner or an organizer"
  end

  def match?(actor, %{action: %{name: :create}} = context, _opts) do
    # For create actions, check against the group_id in the changeset
    case context.changeset do
      %Ash.Changeset{} = changeset ->
        group_id =
          Ash.Changeset.get_argument(changeset, :group_id) ||
            Ash.Changeset.get_attribute(changeset, :group_id)

        check_authorization(actor, group_id)

      _ ->
        false
    end
  end

  def match?(actor, %{resource: _resource} = context, _opts) do
    # For read/update/destroy, check against the huddl's group
    case context.query || context.changeset do
      %Ash.Query{} ->
        # For queries, we can't check individual records
        # This should be handled by query preparations
        true

      %Ash.Changeset{data: huddl} ->
        check_authorization(actor, huddl.group_id)

      _ ->
        false
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp check_authorization(nil, _group_id), do: false
  defp check_authorization(_actor, nil), do: false

  defp check_authorization(actor, group_id) do
    # Check if user is the owner
    case Ash.get(Group, group_id, authorize?: false) do
      {:ok, group} when group.owner_id == actor.id ->
        true

      {:ok, group} ->
        # Check if user is an organizer
        GroupMember
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(group_id: group.id, user_id: actor.id, role: :organizer)
        |> Ash.exists?()

      _ ->
        false
    end
  end
end
