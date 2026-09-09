defmodule Huddlz.Communities.HuddlAttendee.Checks.IsGroupOwnerOrOrganizer do
  @moduledoc """
  Check if the actor is the owner or organizer of the group that owns the huddl.
  Used to allow group management to see attendee lists.
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupMember
  require Ash.Query

  @impl true
  def describe(_opts) do
    "actor is owner or organizer of the huddl's group"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  @impl true
  def match?(actor, context, _opts) do
    huddl_id = get_huddl_id(context)

    if huddl_id && actor do
      check_owner_or_organizer(actor, huddl_id)
    else
      false
    end
  end

  # Extract huddl_id from various contexts
  defp get_huddl_id(%{changeset: %{arguments: %{huddl_id: huddl_id}}}), do: huddl_id
  defp get_huddl_id(%{query: %{arguments: %{huddl_id: huddl_id}}}), do: huddl_id
  defp get_huddl_id(%{record: %{huddl_id: huddl_id}}), do: huddl_id
  defp get_huddl_id(_), do: nil

  # Check if the actor is owner or organizer of the group
  defp check_owner_or_organizer(%{id: user_id} = actor, huddl_id) do
    # Preserve member visibility when looking up archived or private history.
    case Communities.get_huddl(huddl_id, actor: actor) do
      {:ok, %{group_id: group_id}} when not is_nil(group_id) ->
        # Then check if user is owner or organizer of that group
        GroupMember
        |> Ash.Query.filter(
          group_id == ^group_id and
            user_id == ^user_id and
            role in [:owner, :organizer]
        )
        |> Ash.exists?(authorize?: false)

      _ ->
        false
    end
  end
end
