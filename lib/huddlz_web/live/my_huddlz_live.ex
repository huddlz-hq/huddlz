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
        <.button
          variant={if first_run?(@counts), do: :secondary, else: :primary}
          navigate={~p"/discover"}
        >
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
        <.empty_state
          icon={empty_icon(@filter)}
          title={empty_title(@filter, first_run?(@counts))}
          data-first-run={first_run?(@counts) || nil}
        >
          {empty_message(@filter, first_run?(@counts))}
          <:action :if={@filter == :upcoming}>
            <.button :if={first_run?(@counts)} variant={:primary} navigate={~p"/discover"}>
              <.icon name="hero-magnifying-glass" class="size-4" /> Find a huddl
            </.button>
            <.button :if={!first_run?(@counts)} variant={:secondary} navigate={~p"/discover"}>
              Browse huddlz
            </.button>
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

  # A first run is an account with no RSVP history at all. Its empty page
  # says what the page is for and hands over the one action that fills it;
  # once there is history, the same page goes quiet instead.
  defp first_run?(counts), do: counts.upcoming + counts.waitlisted + counts.past == 0

  defp empty_title(:upcoming, true), do: "No upcoming RSVPs yet"
  defp empty_title(:upcoming, false), do: "Nothing coming up"
  defp empty_title(:waitlisted, _first_run), do: "No waitlists"
  defp empty_title(:past, _first_run), do: "Nothing attended yet"

  defp empty_message(:upcoming, true),
    do: "Find a huddl worth showing up to and it will land here."

  defp empty_message(:upcoming, false),
    do: "Your next RSVP will land here."

  defp empty_message(:waitlisted, _first_run),
    do: "You're not on a waitlist right now."

  defp empty_message(:past, _first_run),
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
end
