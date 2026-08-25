defmodule HuddlzWeb.GroupInvitationLive do
  @moduledoc """
  Lets an invited person review and respond to a private-group invitation.
  """

  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    case load_invitation(id, user) do
      {:ok, invitation} ->
        invitation = normalize_expiration(invitation, user)

        {:ok,
         socket
         |> assign(:page_title, "Group invitation")
         |> assign(:invitation, invitation)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That invitation isn't available.")
         |> push_navigate(to: ~p"/notifications?filter=invites")}
    end
  end

  @impl true
  def handle_event("accept", _params, socket) do
    invitation = socket.assigns.invitation

    case invitation.status do
      :pending ->
        accept_invitation(socket, invitation)

      :accepted ->
        {:noreply, put_flash(socket, :info, "You already accepted this invitation.")}

      status ->
        {:noreply, put_flash(socket, :error, unavailable_message(status))}
    end
  end

  def handle_event("decline", _params, socket) do
    invitation = socket.assigns.invitation

    case invitation.status do
      :pending ->
        decline_invitation(socket, invitation)

      :declined ->
        {:noreply, put_flash(socket, :info, "You already declined this invitation.")}

      status ->
        {:noreply, put_flash(socket, :error, unavailable_message(status))}
    end
  end

  defp accept_invitation(socket, invitation) do
    user = socket.assigns.current_user

    case Communities.accept_group_invitation(invitation, actor: user) do
      {:ok, accepted} ->
        {:noreply,
         socket
         |> assign(:invitation, Communities.load_group_invitation_details!(accepted))
         |> put_flash(:info, "Welcome to #{invitation.group.name}.")}

      {:error, _reason} ->
        handle_stale_response(socket, invitation, user)
    end
  end

  defp decline_invitation(socket, invitation) do
    user = socket.assigns.current_user

    case Communities.decline_group_invitation(invitation, actor: user) do
      {:ok, declined} ->
        {:noreply,
         socket
         |> assign(:invitation, Communities.load_group_invitation_details!(declined))
         |> put_flash(:info, "Invitation declined.")}

      {:error, _reason} ->
        handle_stale_response(socket, invitation, user)
    end
  end

  defp handle_stale_response(socket, invitation, user) do
    case load_invitation(invitation.id, user) do
      {:ok, reloaded} ->
        reloaded = normalize_expiration(reloaded, user)

        message =
          if reloaded.status == :pending,
            do: "Something went wrong. Please try again.",
            else: unavailable_message(reloaded.status)

        {:noreply,
         socket
         |> assign(:invitation, reloaded)
         |> put_flash(:error, message)}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "That invitation isn't available.")
         |> push_navigate(to: ~p"/notifications?filter=invites")}
    end
  end

  defp load_invitation(id, user) do
    with {:ok, %GroupInvitation{} = invitation} <-
           Communities.get_my_group_invitation(id, actor: user) do
      {:ok, Communities.load_group_invitation_details!(invitation)}
    end
  end

  defp normalize_expiration(%{status: :pending, expires_at: expires_at} = invitation, user) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      invitation
    else
      invitation
      |> Communities.expire_group_invitation!(actor: user)
      |> Communities.load_group_invitation_details!()
    end
  end

  defp normalize_expiration(invitation, _user), do: invitation

  defp unavailable_message(:revoked), do: "This invitation was revoked."
  defp unavailable_message(:expired), do: "This invitation expired."
  defp unavailable_message(:accepted), do: "This invitation was already accepted."
  defp unavailable_message(:declined), do: "This invitation was already declined."
  defp unavailable_message(_), do: "This invitation is no longer available."

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      unread_notification_count={@unread_notification_count}
      active="notifications"
    >
      <.link
        id="back-to-invitations"
        class="invitation-back-link"
        navigate={~p"/notifications?filter=invites"}
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to invitations
      </.link>

      <div class="page-head">
        <div>
          <h1>Group invitation</h1>
          <p>Review who invited you and choose whether to join.</p>
        </div>
      </div>

      <div id="group-invitation" class="panel max-w-2xl">
        <div class="panel-head invitation-detail-head">
          <div class="min-w-0">
            <h2>{@invitation.group.name}</h2>
            <div class="panel-sub">
              Invited by {@invitation.inviter.display_name} · {role_label(@invitation.role)}
            </div>
          </div>
          <span
            id="invitation-status"
            class={["pill", invitation_status_class(@invitation.status)]}
          >
            {invitation_status_label(@invitation.status)}
          </span>
        </div>

        <p id="invitation-status-description" class="muted">
          {invitation_status_description(@invitation.status)}
        </p>

        <div :if={@invitation.status == :pending} class="actions mt-6">
          <button id="accept-invitation" type="button" class="btn-primary" phx-click="accept">
            Accept invitation
          </button>
          <button id="decline-invitation" type="button" class="btn-secondary" phx-click="decline">
            Decline
          </button>
        </div>

        <div :if={@invitation.status == :accepted} class="panel-cta">
          <.link
            id="open-invited-group"
            class="btn-primary"
            navigate={~p"/groups/#{@invitation.group.slug}"}
          >
            Open group
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp role_label(:organizer), do: "Organizer invitation"
  defp role_label(_), do: "Member invitation"

  defp invitation_status_label(:pending), do: "Awaiting response"
  defp invitation_status_label(:accepted), do: "Accepted"
  defp invitation_status_label(:declined), do: "Declined"
  defp invitation_status_label(:revoked), do: "Revoked"
  defp invitation_status_label(:expired), do: "Expired"

  defp invitation_status_description(:pending) do
    "This private group stays hidden until you accept. Accepting adds it to My groups and gives you access to its roster and huddlz."
  end

  defp invitation_status_description(:accepted) do
    "You accepted this invitation. This private group is now available in My groups."
  end

  defp invitation_status_description(:declined) do
    "You declined this invitation. The private group remains hidden from you."
  end

  defp invitation_status_description(:revoked) do
    "The organizer revoked this invitation, so it can no longer be accepted."
  end

  defp invitation_status_description(:expired) do
    "This invitation expired before it was accepted."
  end

  defp invitation_status_class(:accepted), do: "cyan"
  defp invitation_status_class(status) when status in [:revoked, :expired], do: "muted"
  defp invitation_status_class(_), do: "warn"
end
