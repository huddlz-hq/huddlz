defmodule Huddlz.Communities.GroupInvitation.Changes.SetExpiration do
  @moduledoc false

  use Ash.Resource.Change

  @invitation_lifetime_days 7

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :expires_at,
      DateTime.add(DateTime.utc_now(), @invitation_lifetime_days, :day)
    )
  end
end
