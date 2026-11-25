defmodule Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer do
  @moduledoc """
  Check if the actor is the owner or an organizer of the group.
  Used for create actions where expression policies can't traverse relationships.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.GroupRoles

  def describe(_opts) do
    "actor is the group owner or an organizer"
  end

  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    group_id =
      Ash.Changeset.get_argument(changeset, :group_id) ||
        Ash.Changeset.get_attribute(changeset, :group_id)

    GroupRoles.owns_or_organizes?(actor, group_id)
  end

  def match?(_actor, _context, _opts), do: false
end
