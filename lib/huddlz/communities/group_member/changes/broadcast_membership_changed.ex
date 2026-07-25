defmodule Huddlz.Communities.GroupMember.Changes.BroadcastMembershipChanged do
  @moduledoc """
  Notifies mounted group surfaces after a membership mutation commits.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.MembershipEvents

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, member} = result ->
        MembershipEvents.broadcast(member.group_id)
        result

      _changeset, result ->
        result
    end)
  end
end
