defmodule Huddlz.Communities.Huddl.Changes.NotifyWaitlistPromoted do
  @moduledoc """
  Enqueues `:waitlist_promoted` email when `PromoteFromWaitlist` set
  `:promoted_user_id` in changeset context. Runs after the cancellation
  transaction commits, so we don't email someone whose promotion is
  about to be rolled back.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &notify/2)
  end

  defp notify(cs, huddl) do
    case cs.context[:promoted_user_id] do
      nil ->
        {:ok, huddl}

      user_id ->
        with {:ok, user} <- Ash.get(User, user_id, authorize?: false) do
          Notifications.deliver_async(user, :waitlist_promoted, %{"huddl_id" => huddl.id})
        end

        {:ok, huddl}
    end
  end
end
