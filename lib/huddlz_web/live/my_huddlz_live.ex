defmodule HuddlzWeb.MyHuddlzLive do
  @moduledoc """
  LiveView at `/my-huddlz`. Personal feed of huddlz the signed-in user is
  attending, waitlisted on, or has already attended. Filter chips
  (Upcoming · N / Waitlisted · N / Past) drive a `?filter=` URL param;
  `?page=N` paginates the active filter.

  Hosting moves to the organizer workspace — by design this view is
  participant-centered.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Storage.HuddlImages
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
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

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

  defp parse_page(nil), do: 1
  defp parse_page(""), do: 1

  defp parse_page(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n >= 1 -> n
      _ -> 1
    end
  end

  defp parse_page(val) when is_integer(val) and val >= 1, do: val
  defp parse_page(_), do: 1

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

  defp filter_query(:upcoming), do: {:attending, :upcoming, :soonest}
  defp filter_query(:waitlisted), do: {:waitlisted, :upcoming, :soonest}
  defp filter_query(:past), do: {:attending, :past, :newest}

  defp run_search(user, relationship, date_filter, opts) do
    Communities.search_huddlz(
      nil,
      date_filter,
      nil,
      nil,
      nil,
      nil,
      relationship,
      Keyword.get(opts, :sort, :soonest),
      actor: user,
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
    <Layouts.v3_app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-huddlz"
    >
      <div class="page-head">
        <div>
          <h1>My huddlz</h1>
          <p>{filter_blurb(@filter)}</p>
        </div>
        <.link navigate={~p"/discover"} class="btn-primary">
          Find another huddl
        </.link>
      </div>

      <div class="filters">
        <.v3_chip patch={filter_path(:upcoming, 1)} active={@filter == :upcoming}>
          Upcoming · {@counts.upcoming}
        </.v3_chip>
        <.v3_chip patch={filter_path(:waitlisted, 1)} active={@filter == :waitlisted}>
          Waitlisted · {@counts.waitlisted}
        </.v3_chip>
        <.v3_chip patch={filter_path(:past, 1)} active={@filter == :past}>
          Past · {@counts.past}
        </.v3_chip>
      </div>

      <%= if Enum.empty?(@huddls) do %>
        <p class="muted">{empty_message(@filter)}</p>
      <% else %>
        <div class="grid">
          <%= for {huddl, idx} <- Enum.with_index(@huddls) do %>
            <.v3_my_huddl_card huddl={huddl} filter={@filter} gradient={Integer.mod(idx, 6) + 1} />
          <% end %>
        </div>
        <.v3_pagination
          :if={@page_info.total_pages > 1}
          current_page={@page_info.current_page}
          total_pages={@page_info.total_pages}
          event_name="change_page"
        />
      <% end %>
    </Layouts.v3_app>
    """
  end

  attr :huddl, :map, required: true
  attr :filter, :atom, required: true
  attr :gradient, :integer, required: true

  defp v3_my_huddl_card(assigns) do
    ~H"""
    <.v3_card
      navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}"}
      gradient={@gradient}
    >
      <:cover>
        <img
          :if={@huddl.display_image_url}
          class="card-cover-img"
          src={HuddlImages.url(@huddl.display_image_url)}
          alt={@huddl.title}
        />
        <.v3_date_stamp month={huddl_month(@huddl)} day={huddl_day(@huddl)} />
        <.v3_card_tag variant={tag_variant(@huddl.event_type)}>
          {tag_label(@huddl.event_type)}
        </.v3_card_tag>
      </:cover>
      <:body>
        <span :if={@huddl.group} class="card-group">{@huddl.group.name}</span>
        <h3 class="card-title">{@huddl.title}</h3>
        <div class="card-meta">
          <span>{format_meta_when(@huddl.starts_at)}</span>
          <%= if @huddl.rsvp_count > 0 || @huddl.max_attendees do %>
            <span class="dot"></span>
            <span>{rsvp_label(@huddl)}</span>
          <% end %>
        </div>
      </:body>
      <:foot>
        <.v3_pill variant={pill_variant(@filter)}>{pill_label(@filter)}</.v3_pill>
        <span class="muted" style="font-size:12px">{relative_time(@huddl.starts_at)}</span>
      </:foot>
    </.v3_card>
    """
  end

  defp filter_blurb(:upcoming),
    do: "Everything you've RSVP'd to. Upcoming, soonest first."

  defp filter_blurb(:waitlisted),
    do: "Spots you're holding on a waitlist. We'll bump you up if seats open."

  defp filter_blurb(:past),
    do: "Huddlz you've attended. Most recent first."

  defp empty_message(:upcoming),
    do: "No upcoming RSVPs yet. Find one to attend."

  defp empty_message(:waitlisted),
    do: "You're not on a waitlist right now."

  defp empty_message(:past),
    do: "No past attendance yet."

  defp pill_variant(:upcoming), do: :default
  defp pill_variant(:waitlisted), do: :warn
  defp pill_variant(:past), do: :muted

  defp pill_label(:upcoming), do: "Going"
  defp pill_label(:waitlisted), do: "Waitlist"
  defp pill_label(:past), do: "Attended"

  defp tag_variant(:in_person), do: :in_person
  defp tag_variant(:virtual), do: :online
  defp tag_variant(:hybrid), do: :hybrid

  defp tag_label(:in_person), do: "In person"
  defp tag_label(:virtual), do: "Online"
  defp tag_label(:hybrid), do: "Hybrid"

  defp huddl_month(%{starts_at: %DateTime{} = dt}),
    do: Calendar.strftime(dt, "%b") |> String.upcase()

  defp huddl_day(%{starts_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%-d")

  defp format_meta_when(%DateTime{} = dt) do
    "#{Calendar.strftime(dt, "%a")} · #{Calendar.strftime(dt, "%-I:%M %p")}"
  end

  defp rsvp_label(%{rsvp_count: count, max_attendees: max}) when is_integer(max) and max > 0,
    do: "#{count} / #{max} RSVPs"

  defp rsvp_label(%{rsvp_count: 1}), do: "1 RSVP"
  defp rsvp_label(%{rsvp_count: count}), do: "#{count} RSVPs"

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
