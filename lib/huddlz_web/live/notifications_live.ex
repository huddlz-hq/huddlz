defmodule HuddlzWeb.NotificationsLive do
  @moduledoc """
  LiveView at `/notifications`. Notification inbox for the signed-in user.
  Two filter chips driven by `?filter=`: default `inbox` is no param;
  `invites` shows pending group invitations (a live view of
  `Huddlz.Communities.GroupInvitation`, not a notification log — it reflects
  accept/decline/revoke/expiry immediately). `?page=N` paginates the active
  filter.

  Replaces the `/me?tab=updates` and `/me?tab=invites` tabs from the legacy
  member dashboard. Redirects from those legacy paths land users on the
  matching filter.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.ParamHelpers

  alias Huddlz.Communities
  alias Huddlz.DateTimeFormatting
  alias Huddlz.Notifications
  alias Huddlz.Notifications.Notification
  alias Huddlz.Notifications.Target
  alias HuddlzWeb.Layouts
  require Logger

  @page_size 20
  @valid_filters ~w(inbox invites)

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:items_empty?, true)
     |> assign(
       :viewer_zone,
       DateTimeFormatting.resolve_viewer_zone(
         socket.assigns[:current_user],
         socket.assigns[:browser_time_zone]
       )
     )
     |> assign(:notification_targets, %{})
     |> assign(:counts, %{inbox: 0, invites: 0})
     |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})
     |> stream_configure(:notifications, dom_id: &"notification-#{&1.id}")
     |> stream_configure(:invitations, dom_id: &"invitation-#{&1.id}")
     |> stream(:notifications, [])
     |> stream(:invitations, [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    with {:ok, notification} <- Notifications.get_notification(id, actor: user),
         {:available, destination} <- Target.resolve(notification, user) do
      {:noreply, push_navigate(socket, to: destination)}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:info, resolved_target_message())
         |> push_navigate(to: ~p"/notifications")}
    end
  end

  def handle_params(params, _uri, socket) do
    filter = parse_filter(params["filter"])
    page = parse_page(params["page"])
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:counts, load_counts(user))
      |> load_results(filter, page, user)

    total_pages = socket.assigns.page_info.total_pages

    if page > total_pages do
      {:noreply, push_patch(socket, to: filter_path(filter, total_pages))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = parse_page(page_str)
    {:noreply, push_patch(socket, to: filter_path(socket.assigns.filter, page))}
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    with {:ok, notification} <- Ash.get(Notification, id, actor: user),
         {:ok, _} <- Notifications.mark_read_and_notify(notification, user) do
      {:noreply, refresh(socket, user)}
    else
      {:error, reason} ->
        Logger.warning("NotificationsLive mark_read failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_user

    case Notifications.mark_all_read(user) do
      :ok ->
        {:noreply, refresh(socket, user)}

      {:error, reason} ->
        Logger.warning("NotificationsLive mark_all_read failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  defp refresh(socket, user) do
    socket
    |> assign(:counts, load_counts(user))
    |> load_results(socket.assigns.filter, socket.assigns.page_info.current_page, user)
  end

  defp parse_filter(value) when value in @valid_filters, do: String.to_existing_atom(value)
  defp parse_filter(_), do: :inbox

  defp load_counts(user) do
    %{
      inbox: count_unread_inbox(user),
      invites: count_invites(user)
    }
  end

  defp count_unread_inbox(user) do
    case Notifications.unread_count(user) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp count_invites(user) do
    case Communities.count_pending_group_invitations_for_user(actor: user) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp load_results(socket, filter, page, user) do
    offset = (page - 1) * @page_size

    case fetch_page(filter, user, offset) do
      {:ok, %Ash.Page.Offset{results: results, count: count}} ->
        total_pages = if count && count > 0, do: ceil(count / @page_size), else: 1

        socket
        |> assign_results(filter, results)
        |> assign(:notification_targets, resolve_targets(filter, results, user))
        |> assign(:page_info, %{
          total_pages: total_pages,
          current_page: page,
          total_count: count || 0
        })

      {:error, reason} ->
        Logger.warning("NotificationsLive load failed: #{inspect(reason)}")

        socket
        |> assign_results(filter, [])
        |> assign(:notification_targets, %{})
        |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})
    end
  end

  defp assign_results(socket, :inbox, notifications) do
    socket
    |> assign(:items_empty?, notifications == [])
    |> stream(:notifications, notifications, reset: true)
  end

  defp assign_results(socket, :invites, invitations) do
    socket
    |> assign(:items_empty?, invitations == [])
    |> stream(:invitations, invitations, reset: true)
  end

  defp fetch_page(:inbox, user, offset) do
    Notifications.list_for_user(
      actor: user,
      page: [limit: @page_size, offset: offset, count: true]
    )
  end

  defp fetch_page(:invites, user, offset) do
    Communities.list_pending_group_invitations_for_user(
      actor: user,
      page: [limit: @page_size, offset: offset, count: true]
    )
  end

  defp filter_path(:inbox, page) when page > 1, do: ~p"/notifications?#{[page: page]}"
  defp filter_path(:inbox, _page), do: ~p"/notifications"

  defp filter_path(filter, page) when page > 1,
    do: ~p"/notifications?#{[filter: filter, page: page]}"

  defp filter_path(filter, _page), do: ~p"/notifications?#{[filter: filter]}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="notifications"
    >
      <div class="page-head">
        <div>
          <h1>Notifications</h1>
          <p>{filter_blurb(@filter)}</p>
        </div>
        <div :if={@filter == :inbox and @counts.inbox > 0} class="actions">
          <button type="button" class="btn-secondary" phx-click="mark_all_read">
            Mark all as read
          </button>
        </div>
      </div>

      <div class="filters">
        <.chip patch={filter_path(:inbox, 1)} active={@filter == :inbox}>
          Inbox · {@counts.inbox} unread
        </.chip>
        <.chip patch={filter_path(:invites, 1)} active={@filter == :invites}>
          Invites · {@counts.invites}
        </.chip>
      </div>

      <%= if @items_empty? do %>
        <p class="muted">{empty_message(@filter)}</p>
      <% else %>
        <div class="panel" style="padding:0">
          <div class="row-list" style="padding:6px 20px">
            <%= if @filter == :invites do %>
              <div id="invitation-items" phx-update="stream">
                <.invitation_row
                  :for={{dom_id, invitation} <- @streams.invitations}
                  id={dom_id}
                  invitation={invitation}
                  viewer_zone={@viewer_zone}
                />
              </div>
            <% else %>
              <div id="notification-items" phx-update="stream">
                <.notification_row
                  :for={{dom_id, notification} <- @streams.notifications}
                  id={dom_id}
                  notification={notification}
                  target={Map.get(@notification_targets, notification.id, :none)}
                  viewer_zone={@viewer_zone}
                />
              </div>
            <% end %>
          </div>
        </div>
        <.pagination
          :if={@page_info.total_pages > 1}
          current_page={@page_info.current_page}
          total_pages={@page_info.total_pages}
          event_name="change_page"
        />
      <% end %>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :notification, :map, required: true
  attr :target, :any, required: true
  attr :viewer_zone, :string, required: true

  defp notification_row(assigns) do
    read? = !is_nil(assigns.notification.read_at)
    assigns = assign(assigns, :unread, !read?)

    ~H"""
    <div
      id={@id}
      class={["row", "notif-row", @unread && "unread"]}
    >
      <div class={["notif-mark", mark_color(@notification)]} aria-hidden="true"></div>
      <div>
        <div class="row-title">{@notification.title}</div>
        <div :if={meta_line(@notification, @viewer_zone)} class="meta">
          {meta_line(@notification, @viewer_zone)}
        </div>
      </div>
      <div
        :if={@target != :none or @unread}
        class="notif-actions"
        id={"notification-actions-#{@notification.id}"}
      >
        <.link
          :if={match?({:available, _}, @target)}
          id={"notification-#{@notification.id}-open"}
          class="pill"
          navigate={~p"/notifications/#{@notification.id}/open"}
          aria-label={"Open #{@notification.title}"}
        >
          Open
        </.link>
        <span
          :if={@target == :resolved}
          id={"notification-#{@notification.id}-resolved"}
          class="notif-resolved"
        >
          Destination unavailable
        </span>
        <button
          :if={@unread}
          type="button"
          class="pill"
          id={"mark-notification-read-#{@notification.id}"}
          phx-click="mark_read"
          phx-value-id={@notification.id}
          phx-disable-with="Marking…"
          aria-label={"Mark #{@notification.title} as read"}
        >
          Mark read
        </button>
      </div>
    </div>
    """
  end

  defp resolve_targets(:inbox, notifications, user) do
    Map.new(notifications, fn notification ->
      {notification.id, Target.resolve(notification, user)}
    end)
  end

  defp resolve_targets(:invites, _invitations, _user), do: %{}

  defp resolved_target_message,
    do: "That notification destination is no longer available or you no longer have access."

  attr :id, :string, required: true
  attr :invitation, :map, required: true
  attr :viewer_zone, :string, required: true

  defp invitation_row(assigns) do
    ~H"""
    <div id={@id} class="row notif-row invitation-row">
      <div class="notif-mark cyan" aria-hidden="true"></div>
      <div>
        <div class="row-title">Invitation to {@invitation.group.name}</div>
        <div class="meta">{invitation_meta_line(@invitation, @viewer_zone)}</div>
      </div>
      <div class="notif-actions" id={"invitation-actions-#{@invitation.id}"}>
        <.link
          id={"open-invitation-#{@invitation.id}"}
          class="pill invitation-open-action"
          navigate={~p"/invitations/#{@invitation.id}"}
          aria-label={"Open invitation to #{@invitation.group.name}"}
        >
          Open
        </.link>
      </div>
    </div>
    """
  end

  defp invitation_meta_line(%{inviter: inviter, role: role, inserted_at: at}, viewer_zone) do
    "Invited by #{inviter.display_name} · #{invitation_role_label(role)} · #{format_time_ago(at, viewer_zone)}"
  end

  defp invitation_role_label(:organizer), do: "Organizer"
  defp invitation_role_label(_), do: "Member"

  defp filter_blurb(:inbox),
    do: "RSVPs, group activity, and reminders from across huddlz."

  defp filter_blurb(:invites),
    do: "Things that need a response from you."

  defp empty_message(:inbox),
    do: "No notifications yet. Reminders and group activity will appear here as they happen."

  defp empty_message(:invites),
    do: "No pending invitations. When organizers invite you to a group, they'll show up here."

  defp mark_color(%{read_at: %DateTime{}}), do: "muted"

  defp mark_color(%{trigger: trigger}) when is_binary(trigger) do
    if trigger in transactional_triggers(), do: "warn", else: "cyan"
  end

  defp mark_color(_), do: "cyan"

  # Memoized at module load — Triggers.all/0 is a compile-time map. Using a
  # string set lets us match the DB-stored trigger string directly without
  # converting to an atom (which would risk ArgumentError on stale rows).
  @transactional_triggers Notifications.Triggers.all()
                          |> Enum.filter(fn {_, e} -> e.category == :transactional end)
                          |> Enum.map(fn {trigger, _} -> Atom.to_string(trigger) end)
                          |> MapSet.new()

  defp transactional_triggers, do: @transactional_triggers

  defp meta_line(notification, viewer_zone)

  defp meta_line(%{description: desc, inserted_at: %DateTime{} = at}, viewer_zone)
       when is_binary(desc) and desc != "" do
    "#{desc} · #{format_time_ago(at, viewer_zone)}"
  end

  defp meta_line(%{inserted_at: %DateTime{} = at}, viewer_zone),
    do: format_time_ago(at, viewer_zone)

  defp meta_line(_, _viewer_zone), do: nil

  # `inserted_at` is when the notification was delivered — no huddl involved —
  # so the absolute fallback is rendered in the viewer's own zone (their
  # preference, else the browser-detected one), matching the calendar's
  # viewer-only zone resolution.
  defp format_time_ago(%DateTime{} = dt, viewer_zone) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 7 * 86_400 -> "#{div(diff, 86_400)}d ago"
      true -> dt |> DateTimeFormatting.shift(viewer_zone) |> Calendar.strftime("%b %d, %Y")
    end
  end
end
