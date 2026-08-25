defmodule Huddlz.Communities.GroupInvitation.Preparations.LoadPendingDetails do
  @moduledoc """
  Loads the group and inviter needed by the pending-invitations list.

  A pending invitee cannot read a private group through the group's normal
  policy until they accept. The invitation read action authorizes the invitee
  first, so these display-only relationships are loaded without running their
  separate resource policies.
  """

  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.after_action(query, fn _query, invitations ->
      Ash.load(invitations, [:group, :inviter], authorize?: false)
    end)
  end
end
