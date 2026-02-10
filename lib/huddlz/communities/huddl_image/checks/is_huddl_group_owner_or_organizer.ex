defmodule Huddlz.Communities.HuddlImage.Checks.IsHuddlGroupOwnerOrOrganizer do
  @moduledoc """
  Check that verifies the actor is the owner or organizer of the group
  that the huddl belongs to.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.{Group, GroupMember, Huddl}
  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is the owner or organizer of the huddl's group"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: changeset}, _opts) do
    # Get huddl_id from argument (for assign_to_huddl) or attribute (for create)
    huddl_id =
      Ash.Changeset.get_argument(changeset, :huddl_id) ||
        Ash.Changeset.get_attribute(changeset, :huddl_id)

    group_owner_or_organizer?(actor, huddl_id)
  end

  def match?(actor, %{record: record}, _opts) do
    # For existing records, get the huddl_id from the record
    group_owner_or_organizer?(actor, record.huddl_id)
  end

  def match?(_actor, _context, _opts), do: false

  defp group_owner_or_organizer?(_actor, nil), do: false

  defp group_owner_or_organizer?(actor, huddl_id) do
    # Get the huddl to find its group_id
    case Ash.get(Huddl, huddl_id, authorize?: false) do
      {:ok, %Huddl{group_id: group_id}} ->
        check_authorization(actor, group_id)

      _ ->
        false
    end
  end

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
        |> Ash.exists?(authorize?: false)

      _ ->
        false
    end
  end
end
