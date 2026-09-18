defmodule Huddlz.Communities.GroupMember.Changes.CloseDropInReminder do
  @moduledoc """
  Leaving a group, or being removed from it, says more than not joining ever
  could. Once the membership is gone, close the person's reminder for that
  group so huddlz never suggests joining it again (ADR-0011).
  """

  use Ash.Resource.Change

  alias Huddlz.Communities

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, membership ->
      with {:ok, _reminder} <-
             Communities.close_drop_in_reminder(
               %{group_id: membership.group_id, user_id: membership.user_id},
               authorize?: false
             ) do
        {:ok, membership}
      end
    end)
  end
end
