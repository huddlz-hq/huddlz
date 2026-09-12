defmodule HuddlzWeb.EmailChangeLive do
  use HuddlzWeb, :live_view
  alias Huddlz.Accounts.EmailChange
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    pending =
      case EmailChange.review(token) do
        {:ok, pending} -> pending
        _ -> nil
      end

    {:ok,
     assign(socket,
       token: token,
       pending: pending,
       result: nil,
       page_title: "Approve email change"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
    >
      <div class="mx-auto w-full max-w-xl space-y-6 break-words p-6">
        <h1 class="text-2xl font-semibold">Approve email change</h1>
        <%= cond do %>
          <% @result -> %>
            <p role="status">{@result}</p>
            <.link navigate={~p"/profile"}>Go to profile settings</.link>
            <.link navigate={~p"/reset"}>Reset your password</.link>
          <% @pending -> %>
            <p>Change from {@pending["old_email"]} to {@pending["new_email"]}.</p>
            <p>Both inboxes must approve before your sign-in and recovery address changes.</p>
            <div class="flex flex-wrap gap-3">
              <.button variant={:primary} phx-click="approve" phx-disable-with="Approving…">Approve email change</.button>
              <.button phx-click="report" phx-disable-with="Cancelling…">Report and cancel this request</.button>
            </div>
          <% true -> %>
            <p>This approval link is invalid, expired, or already used.</p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("report", _params, socket) do
    result =
      case EmailChange.report(socket.assigns.token) do
        {:ok, _} ->
          "Request reported and cancelled. No email address was changed. If you own this huddlz account, reset your password to secure it."

        {:error, _} ->
          "This request is no longer pending."
      end

    {:noreply, assign(socket, result: result)}
  end

  @impl true
  def handle_event("approve", _params, socket) do
    result =
      case EmailChange.approve(socket.assigns.token) do
        {:ok, %{pending_email_change: nil}} ->
          "Your email address has been changed"

        {:ok, _} ->
          "Approval recorded. The other inbox still needs to approve."

        {:error, _} ->
          "This approval could not be completed. The link may be expired or used, or the address may already be in use."
      end

    {:noreply, assign(socket, result: result)}
  end
end
