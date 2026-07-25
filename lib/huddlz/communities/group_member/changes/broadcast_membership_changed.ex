defmodule Huddlz.Communities.GroupMember.Changes.BroadcastMembershipChanged do
  @moduledoc """
  Broadcasts a committed membership create, update, or destroy.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.MembershipEvents

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, member} = result ->
        MembershipEvents.broadcast(member.group_id, member.user_id)
        result

      _changeset, result ->
        result
    end)
  end
end
