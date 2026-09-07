defmodule Huddlz.Communities.GroupInvitation.ConfirmedRecipientWorker do
  @moduledoc "Makes pending email invitations available after email ownership is confirmed."
  use Oban.Worker, queue: :notifications, max_attempts: 5, unique: [period: 60]

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation
  alias Huddlz.Communities.GroupInvitation.EmailToken

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => id, "email" => email}}) do
    case Ash.get(User, id, authorize?: false, not_found_error?: false) do
      {:ok, %User{} = user} ->
        if Ash.CiString.compare(user.email, email) == :eq,
          do: claim_invitations(user, email),
          else: :ok

      {:ok, nil} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp claim_invitations(user, email) do
    GroupInvitation
    |> Ash.Query.filter(
      email == ^email and is_nil(invitee_id) and status == :pending and expires_at > now()
    )
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, invitations} ->
        Enum.reduce_while(invitations, :ok, &claim_invitation(&1, &2, user))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp claim_invitation(invitation, :ok, user) do
    # The queued confirmation proves ownership of this exact email.
    # Reuse the locked claim action and its one-time notification path.
    case Communities.open_email_group_invitation(EmailToken.sign(invitation), actor: user) do
      {:ok, _invitation} -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end
end
