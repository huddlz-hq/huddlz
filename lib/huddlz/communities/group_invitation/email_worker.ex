defmodule Huddlz.Communities.GroupInvitation.EmailWorker do
  @moduledoc "Delivers new-recipient invitations with retry, without creating placeholder accounts."
  use Oban.Worker, queue: :notifications, max_attempts: 5, unique: [period: 60]

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupInvitation
  alias Huddlz.Communities.GroupInvitation.EmailToken
  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout
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

  @doc "The email for an invitation to an address without an account, for tests and samples."
  def build(invitation) do
    url = Endpoint.url() <> "/invitations/email/" <> EmailToken.sign(invitation)
    name = to_string(invitation.group.name)
    inviter = invitation.inviter.display_name

    Layout.email(%{
      to: invitation.email,
      subject: "Invitation to #{name}",
      kicker: "Invitation",
      title: "#{inviter} invited you to #{name}",
      paragraphs: [
        [{:strong, inviter}, " invited you to join ", {:strong, name}, " on huddlz."],
        "Register or sign in with this email address to review the invitation and accept or decline. Joining is always your choice."
      ],
      action: {"Review invitation", url},
      aside:
        "This invitation expires after 7 days. If you weren't expecting it, you can ignore this email.",
      footer:
        Footer.account(
          "You're receiving this email because someone invited this address to a group on huddlz."
        )
    })
  end

  defp deliver_if_allowed(invitation) do
    # Registration may happen while this email waits. Confirmation makes the
    # invitation available in-app and queues the normal registered-user email,
    # which applies confirmation, preferences, and the activity footer.
    User
    |> Ash.Query.for_read(:get_by_email, %{email: invitation.email})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> deliver(invitation)
      {:ok, %User{}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp deliver(invitation) do
    case invitation |> build() |> Mailer.deliver() do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
