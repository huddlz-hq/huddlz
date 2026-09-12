defmodule Huddlz.Accounts.User.Changes.ApproveEmailChange do
  @moduledoc false
  use Ash.Resource.Change
  alias Huddlz.Accounts.EmailChange
  alias Huddlz.Communities.GroupInvitation.ConfirmedRecipientWorker

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&approve/1)
    |> Ash.Changeset.after_action(&queue_confirmed_invitations/2)
  end

  defp queue_confirmed_invitations(%{data: %{email: email}}, %{email: email} = user),
    do: {:ok, user}

  defp queue_confirmed_invitations(_changeset, user) do
    with {:ok, _} <-
           Oban.insert(
             ConfirmedRecipientWorker.new(%{
               user_id: user.id,
               email: to_string(user.email)
             })
           ) do
      {:ok, user}
    end
  end

  defp approve(changeset) do
    user = changeset.data

    with {:ok, {user_id, request_id, side}} <-
           EmailChange.verify(Ash.Changeset.get_argument(changeset, :token)),
         true <- user_id == user.id,
         %{"id" => ^request_id} = pending <- user.pending_email_change,
         true <- EmailChange.active?(pending),
         true <- pending["old_email"] == to_string(user.email),
         false <- pending[side <> "_approved"] do
      pending = Map.put(pending, side <> "_approved", true)
      apply_approval(changeset, pending)
    else
      _ ->
        Ash.Changeset.add_error(changeset,
          field: :token,
          message: "This approval link is invalid, expired, or already used."
        )
    end
  end

  defp apply_approval(changeset, %{"old_approved" => true, "new_approved" => true} = pending) do
    # The users' unique_email database index arbitrates competing completions.
    changeset
    |> Ash.Changeset.force_change_attribute(:email, pending["new_email"])
    |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:pending_email_change, nil)
  end

  defp apply_approval(changeset, pending) do
    Ash.Changeset.force_change_attribute(changeset, :pending_email_change, pending)
  end
end
