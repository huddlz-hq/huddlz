defmodule Huddlz.Communities.GroupInvitation.EmailWorker do
  @moduledoc "Delivers new-recipient invitations with retry, without creating placeholder accounts."
  use Oban.Worker, queue: :notifications, max_attempts: 5, unique: [period: 60]

  import Swoosh.Email

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupInvitation
  alias Huddlz.Communities.GroupInvitation.EmailToken
  alias Huddlz.Mailer
  alias Huddlz.Notifications
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape
  alias HuddlzWeb.Endpoint

  @impl true
  def perform(%Oban.Job{args: %{"invitation_id" => id}}) do
    case Ash.get(GroupInvitation, id,
           authorize?: false,
           not_found_error?: false,
           load: [:group, :inviter]
         ) do
      {:ok, %{status: :pending, invitee_id: nil} = invitation} ->
        if DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :gt,
          do: deliver_if_allowed(invitation),
          else: :ok

      {:ok, _invitation} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp deliver_if_allowed(invitation) do
    # The account may have been created while this email waited in the queue.
    # Its preferences apply immediately, even before the invitation is claimed.
    User
    |> Ash.Query.for_read(:get_by_email, %{email: invitation.email})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> deliver(invitation)
      {:ok, user} -> deliver_for_user(invitation, user)
      {:error, reason} -> {:error, reason}
    end
  end

  defp deliver_for_user(invitation, user) do
    if Notifications.preference_for(user, :group_invitation),
      do: deliver(invitation),
      else: :ok
  end

  defp deliver(invitation) do
    url = Endpoint.url() <> "/invitations/email/" <> EmailToken.sign(invitation)
    name = to_string(invitation.group.name)
    inviter = invitation.inviter.display_name

    email =
      new()
      |> from(Mailer.from())
      |> to(to_string(invitation.email))
      |> subject(HeaderSafe.safe("Invitation to #{name}"))
      |> text_body("""
      #{inviter} invited you to join "#{name}" on huddlz.
      Register or sign in with this email address to review and accept or decline.
      This invitation expires after 7 days. Joining is always your choice.
      Review invitation: #{url}
      If you weren't expecting this invitation, you can ignore this email.
      """)
      |> html_body("""
      <p>#{HtmlEscape.escape(inviter)} invited you to join
      <strong>#{HtmlEscape.escape(name)}</strong> on huddlz.</p>
      <p>Register or sign in with this email address to review and accept or decline.</p>
      <p>This invitation expires after 7 days. Joining is always your choice.</p>
      <p><a href="#{HtmlEscape.escape(url)}">Review invitation</a></p>
      <p>If you weren't expecting this invitation, you can ignore this email.</p>
      """)

    case Mailer.deliver(email) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
