defmodule HuddlzWeb.MyHuddlzLive do
  @moduledoc """
  LiveView at `/my-huddlz`. Personal feed of huddlz the signed-in user is
  attending, waitlisted on, or has already attended. Filter chips
  (Upcoming N / Waitlisted N / Past N) drive a `?filter=` URL param;
  `?page=N` paginates the active filter.

  Hosting moves to the organizer workspace — by design this view is
  participant-centered.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.HuddlCardHelpers
  import HuddlzWeb.Live.Helpers.ParamHelpers

  alias Huddlz.Communities
  alias HuddlzWeb.HuddlStatus
  alias HuddlzWeb.Layouts
  require Logger

  @card_loads [
    :status,
    :rsvp_count,
    :visible_virtual_link,
    :display_image_url,
    :group
  ]
  @page_size 20
  @valid_filters ~w(upcoming waitlisted past)

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My huddlz")
     |> assign(:huddls, [])
     |> assign(:counts, %{upcoming: 0, waitlisted: 0, past: 0})
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

  defp parse_filter(value) when value in @valid_filters, do: String.to_existing_atom(value)
  defp parse_filter(_), do: :upcoming

  defp load_counts(user) do
    %{
      upcoming: count_for(user, :attending, :upcoming),
      waitlisted: count_for(user, :waitlisted, :upcoming),
      past: count_for(user, :attending, :past)
    }
  end

  defp count_for(user, relationship, date_filter) do
    case run_search(user, relationship, date_filter, page: [limit: 1, offset: 0, count: true]) do
      {:ok, %{count: count}} when is_integer(count) -> count
      _ -> 0
    end
  end

  defp load_results(socket, filter, page, user) do
    {relationship, date_filter, sort} = filter_query(filter)
    offset = (page - 1) * @page_size

    case run_search(user, relationship, date_filter,
           sort: sort,
           page: [limit: @page_size, offset: offset, count: true]
         ) do
      {:ok, %Ash.Page.Offset{results: results, count: count}} ->
        total_pages = if count && count > 0, do: ceil(count / @page_size), else: 1

        socket
        |> assign(:huddls, results)
        |> assign(:page_info, %{
          total_pages: total_pages,
          current_page: page,
          total_count: count || 0
        })

      {:error, reason} ->
        Logger.warning("MyHuddlzLive search failed: #{inspect(reason)}")

        socket
        |> assign(:huddls, [])
        |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})
    end
  end

  defp filter_query(:upcoming), do: {:attending, :upcoming, [starts_at: :asc]}
  defp filter_query(:waitlisted), do: {:waitlisted, :upcoming, [starts_at: :asc]}
  defp filter_query(:past), do: {:attending, :past, [inserted_at: :desc]}

  defp run_search(user, relationship, date_filter, opts) do
    Communities.search_huddlz(
      nil,
      date_filter,
      nil,
      nil,
      nil,
      nil,
      relationship,
      actor: user,
      query: [sort: Keyword.get(opts, :sort, [])],
      page: Keyword.get(opts, :page, []),
      load: @card_loads
    )
  end

  defp filter_path(:upcoming, page) when page > 1, do: ~p"/my-huddlz?#{[page: page]}"
  defp filter_path(:upcoming, _page), do: ~p"/my-huddlz"

  defp filter_path(filter, page) when page > 1,
    do: ~p"/my-huddlz?#{[filter: filter, page: page]}"

  defp filter_path(filter, _page), do: ~p"/my-huddlz?#{[filter: filter]}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-huddlz"
    >
      <div class="page-head">
        <div>
          <h1>My huddlz</h1>
          <p>{filter_blurb(@filter)}</p>
        </div>
        <.button variant={:primary} navigate={~p"/discover"}>
          <.icon name="hero-magnifying-glass" class="size-4" /> Find another huddl
        </.button>
      </div>

      <div class="filters">
        <.chip
          patch={filter_path(:upcoming, 1)}
          active={@filter == :upcoming}
          count={@counts.upcoming}
        >
          Upcoming
        </.chip>
        <.chip
          patch={filter_path(:waitlisted, 1)}
          active={@filter == :waitlisted}
          count={@counts.waitlisted}
        >
          Waitlisted
        </.chip>
        <.chip patch={filter_path(:past, 1)} active={@filter == :past} count={@counts.past}>
          Past
        </.chip>
      </div>

      <%= if Enum.empty?(@huddls) do %>
        <.empty_state icon={empty_icon(@filter)} title={empty_title(@filter)}>
          {empty_message(@filter)}
          <:action :if={@filter == :upcoming}>
            <.button variant={:secondary} navigate={~p"/discover"}>Browse huddlz</.button>
          </:action>
        </.empty_state>
      <% else %>
        <div class="grid">
          <.my_huddl_card :for={huddl <- @huddls} huddl={huddl} filter={@filter} />
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

  attr :huddl, :map, required: true
  attr :filter, :atom, required: true

  defp my_huddl_card(assigns) do
    ~H"""
    <.card navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}"}>
      <:cover>
        <%= if @huddl.display_image_url do %>
          <.cover_image
            id={"my-huddl-card-cover-#{@huddl.id}"}
            class="card-cover-img"
            image_url={@huddl.display_image_url}
          />
        <% else %>
          <.cover_fallback name={@huddl.group.name} />
        <% end %>
        <.date_stamp month={huddl_month(@huddl)} day={huddl_day(@huddl)} />
        <.card_tag variant={tag_variant(@huddl.event_type)}>
          {tag_label(@huddl.event_type)}
        </.card_tag>
      </:cover>
      <:body>
        <span :if={@huddl.group} class="card-group">{@huddl.group.name}</span>
        <h3 class="card-title">{@huddl.title}</h3>
        <div class="card-meta">
          <span>{format_meta_when(@huddl)}</span>
          <%= if @huddl.rsvp_count > 0 || @huddl.max_attendees do %>
            <span class="dot"></span>
            <span>{rsvp_label(@huddl)}</span>
          <% end %>
        </div>
      </:body>
      <:foot>
        <.pill variant={pill_variant(@huddl, @filter)}>
          {pill_label(@huddl, @filter)}
        </.pill>
        <span class="card-foot-note">{relative_time(@huddl.starts_at)}</span>
      </:foot>
    </.card>
    """
  end

  defp filter_blurb(:upcoming),
    do: "Everything you've RSVP'd to. Upcoming, soonest first."

  defp filter_blurb(:waitlisted),
    do: "Spots you're holding on a waitlist. We'll bump you up if seats open."

  defp filter_blurb(:past),
    do: "Huddlz you've attended. Most recent first."

  defp empty_icon(:upcoming), do: "hero-calendar"
  defp empty_icon(:waitlisted), do: "hero-clock"
  defp empty_icon(:past), do: "hero-check-circle"

  defp empty_title(:upcoming), do: "Nothing coming up"
  defp empty_title(:waitlisted), do: "No waitlists"
  defp empty_title(:past), do: "Nothing attended yet"

  defp empty_message(:upcoming),
    do: "No upcoming RSVPs yet. Find one to attend."

  defp empty_message(:waitlisted),
    do: "You're not on a waitlist right now."

  defp empty_message(:past),
    do: "No past attendance yet."

  defp pill_variant(%{status: status}, filter) do
    case HuddlStatus.contextual_override(status) do
      %{variant: variant} -> variant
      nil -> filter_pill_variant(filter)
    end
  end

  defp filter_pill_variant(:upcoming), do: :cyan
  defp filter_pill_variant(:waitlisted), do: :warn
  defp filter_pill_variant(:past), do: :muted

  defp pill_label(%{status: status}, filter) do
    case HuddlStatus.contextual_override(status) do
      %{label: label} -> label
      nil -> filter_pill_label(filter)
    end
  end

  defp filter_pill_label(:upcoming), do: "Going"
  defp filter_pill_label(:waitlisted), do: "Waitlist"
  defp filter_pill_label(:past), do: "Attended"

  defp relative_time(%DateTime{} = dt) do
    diff_seconds = DateTime.diff(dt, DateTime.utc_now(), :second)
    abs_seconds = abs(diff_seconds)
    future? = diff_seconds >= 0

    cond do
      abs_seconds < 3600 -> if future?, do: "starting soon", else: "just ended"
      abs_seconds < 86_400 -> format_hours(div(abs_seconds, 3600), future?)
      abs_seconds < 7 * 86_400 -> format_days(div(abs_seconds, 86_400), future?)
      abs_seconds < 30 * 86_400 -> format_weeks(div(abs_seconds, 7 * 86_400), future?)
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end

  defp format_hours(1, true), do: "1 hour away"
  defp format_hours(n, true), do: "#{n} hours away"
  defp format_hours(1, false), do: "1 hour ago"
  defp format_hours(n, false), do: "#{n} hours ago"

  defp format_days(1, true), do: "tomorrow"
  defp format_days(n, true), do: "#{n} days away"
  defp format_days(1, false), do: "yesterday"
  defp format_days(n, false), do: "#{n} days ago"

  defp format_weeks(1, true), do: "1 week away"
  defp format_weeks(n, true), do: "#{n} weeks away"
  defp format_weeks(1, false), do: "1 week ago"
  defp format_weeks(n, false), do: "#{n} weeks ago"
end
