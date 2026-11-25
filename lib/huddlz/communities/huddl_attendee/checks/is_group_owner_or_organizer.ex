defmodule Huddlz.Communities.HuddlAttendee.Checks.IsGroupOwnerOrOrganizer do
  @moduledoc """
  Check if the actor is the owner or organizer of the group that owns the huddl.
  Used to authorize reads of the waitlist.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupRoles

  @impl true
  def describe(_opts) do
    "actor is owner or organizer of the huddl's group"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  @impl true
  def match?(actor, context, _opts) do
    with huddl_id when not is_nil(huddl_id) <- get_huddl_id(context),
         {:ok, %{group_id: group_id}} when not is_nil(group_id) <-
           Communities.get_huddl(huddl_id, actor: actor) do
      GroupRoles.has_membership_role?(actor, group_id, [:owner, :organizer])
    else
      _ -> false
    end
  end

  # Extract huddl_id from various contexts
  defp get_huddl_id(%{changeset: %{arguments: %{huddl_id: huddl_id}}}), do: huddl_id
  defp get_huddl_id(%{query: %{arguments: %{huddl_id: huddl_id}}}), do: huddl_id
  defp get_huddl_id(%{record: %{huddl_id: huddl_id}}), do: huddl_id
  defp get_huddl_id(_), do: nil
end
