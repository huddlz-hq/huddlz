defmodule HuddlzWeb.NotificationsLive do
  @moduledoc """
  LiveView at `/notifications`. Notification inbox for the signed-in user.
  Two filter chips driven by `?filter=`: default `inbox` is no param;
  `invites` narrows to notifications that need a response. `?page=N`
  paginates the active filter.

  Replaces the `/me?tab=updates` and `/me?tab=invites` tabs from the legacy
  member dashboard. Redirects from those legacy paths land users on the
  matching filter.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.ParamHelpers

  alias Huddlz.Notifications
  alias Huddlz.Notifications.Notification
  alias HuddlzWeb.Layouts
  require Ash.Query
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
     |> assign(:notifications, [])
     |> assign(:counts, %{inbox: 0, invites: 0})
     |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})}
  end

  @impl true
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
         {:ok, _} <- Notifications.mark_read(notification, actor: user) do
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
    Notification
    |> Ash.Query.for_read(:for_user, %{}, actor: user)
    |> Ash.Query.filter(is_nil(read_at))
    |> Ash.count()
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp count_invites(user) do
    case Notifications.list_invites_for_user(
           actor: user,
           page: [limit: 1, offset: 0, count: true]
         ) do
      {:ok, %{count: count}} when is_integer(count) -> count
      _ -> 0
    end
  end

  defp load_results(socket, filter, page, user) do
    offset = (page - 1) * @page_size

    case fetch_page(filter, user, offset) do
      {:ok, %Ash.Page.Offset{results: results, count: count}} ->
        total_pages = if count && count > 0, do: ceil(count / @page_size), else: 1

        socket
        |> assign(:notifications, results)
        |> assign(:page_info, %{
          total_pages: total_pages,
          current_page: page,
          total_count: count || 0
        })

      {:error, reason} ->
        Logger.warning("NotificationsLive load failed: #{inspect(reason)}")

        socket
        |> assign(:notifications, [])
        |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})
    end
  end

  defp fetch_page(:inbox, user, offset) do
    Notifications.list_for_user(
      actor: user,
      page: [limit: @page_size, offset: offset, count: true]
    )
  end

  defp fetch_page(:invites, user, offset) do
    Notifications.list_invites_for_user(
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

      <%= if Enum.empty?(@notifications) do %>
        <p class="muted">{empty_message(@filter)}</p>
      <% else %>
        <div class="panel" style="padding:0">
          <div class="row-list" style="padding:6px 20px">
            <%= for notification <- @notifications do %>
              <.notification_row notification={notification} />
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

  attr :notification, :map, required: true

  defp notification_row(assigns) do
    read? = !is_nil(assigns.notification.read_at)
    assigns = assign(assigns, :unread, !read?)

    ~H"""
    <div
      id={"notification-#{@notification.id}"}
      class={["row", "notif-row", @unread && "unread"]}
    >
      <div class={["notif-mark", mark_color(@notification)]} aria-hidden="true"></div>
      <div>
        <div class="row-title">{@notification.title}</div>
        <div :if={meta_line(@notification)} class="meta">{meta_line(@notification)}</div>
      </div>
      <%= if @notification.source_url do %>
        <.link class="pill" navigate={@notification.source_url}>Open</.link>
      <% else %>
        <button
          :if={@unread}
          type="button"
          class="pill"
          phx-click="mark_read"
          phx-value-id={@notification.id}
        >
          Mark read
        </button>
      <% end %>
    </div>
    """
  end

  defp filter_blurb(:inbox),
    do: "RSVPs, group activity, and reminders from across huddlz."

  defp filter_blurb(:invites),
    do: "Things that need a response from you."

  defp empty_message(:inbox),
    do: "No notifications yet. Reminders and group activity will appear here as they happen."

  defp empty_message(:invites),
    do:
      "No invites right now. When organizers invite you to a huddl or group, they'll show up here."

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

  defp meta_line(%{description: desc, inserted_at: %DateTime{} = at})
       when is_binary(desc) and desc != "" do
    "#{desc} · #{format_time_ago(at)}"
  end

  defp meta_line(%{inserted_at: %DateTime{} = at}), do: format_time_ago(at)
  defp meta_line(_), do: nil

  defp format_time_ago(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 7 * 86_400 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end
end
