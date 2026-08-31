defmodule HuddlzWeb.CalendarLive do
  @moduledoc """
  LiveView at `/calendar`. Calendar opens on Today and presents confirmed
  RSVP huddlz in chronological order. Legacy month and agenda views remain
  available while the unified Calendar is delivered incrementally.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities
  alias HuddlzWeb.HuddlStatus
  alias HuddlzWeb.Layouts
  require Logger

  defmodule EntryStatus do
    @moduledoc false

    @enforce_keys [:key, :label, :variant, :rank]
    defstruct [:key, :label, :variant, :rank]
  end

  @card_loads [
    :status,
    :group,
    :group_location,
    :rsvp_count,
    :display_image_url,
    :confirmed_rsvp_for_actor,
    :waitlisted_rsvp_for_actor
  ]

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    time_zone = device_time_zone(socket)
    today = today_in(time_zone)

    {:ok,
     socket
     |> assign(:page_title, "Calendar")
     |> assign(:time_zone, time_zone)
     |> assign(:today, today)
     |> stream_configure(:today_entries, dom_id: &"calendar-huddl-#{&1.huddl.id}")
     |> stream_configure(:legend_items, dom_id: &"calendar-legend-item-#{&1.key}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_calendar(socket, params)}
  end

  @impl true
  def handle_event("calendar:set-time-zone", %{"timezone" => time_zone}, socket) do
    {:noreply, refresh_time_zone(socket, time_zone)}
  end

  def handle_event("calendar:set-time-zone", _params, socket) do
    {:noreply, refresh_time_zone(socket, "Etc/UTC")}
  end

  defp refresh_time_zone(socket, time_zone) do
    time_zone = valid_time_zone_or_utc(time_zone)

    socket
    |> assign(:time_zone, time_zone)
    |> assign(:today, today_in(time_zone))
    |> assign_calendar(socket.assigns.calendar_params)
  end

  defp assign_calendar(socket, params) do
    focus_month = parse_month(params["month"], socket.assigns.today)
    view_mode = parse_view(params)
    {grid_start, grid_end} = month_grid_window(focus_month)
    user = socket.assigns.current_user

    entries =
      load_entries(
        user,
        view_mode,
        grid_start,
        grid_end,
        socket.assigns.today,
        socket.assigns.time_zone
      )

    entries_by_day = group_by_day(entries)
    in_month_count = Enum.count(entries, &in_focus_month?(&1.huddl, focus_month))
    legend_items = legend_items(entries, focus_month, view_mode, socket.assigns.today)

    socket
    |> assign(:calendar_params, params)
    |> assign(:focus_month, focus_month)
    |> assign(:view_mode, view_mode)
    |> assign(:grid_start, grid_start)
    |> assign(:grid_end, grid_end)
    |> assign(:entries, entries)
    |> assign(:entries_by_day, entries_by_day)
    |> assign(:in_month_count, in_month_count)
    |> assign(:today_empty?, entries == [])
    |> assign(:legend_empty?, legend_items == [])
    |> stream(:today_entries, entries, reset: true)
    |> stream(:legend_items, legend_items, reset: true)
  end

  defp parse_month(nil, today), do: first_of_month(today)

  defp parse_month(value, today) when is_binary(value) do
    case Regex.run(~r/^(\d{4})-(\d{2})$/, value) do
      [_, y, m] ->
        with {year, ""} <- Integer.parse(y),
             {month, ""} <- Integer.parse(m),
             {:ok, date} <- Date.new(year, month, 1) do
          date
        else
          _ -> first_of_month(today)
        end

      _ ->
        first_of_month(today)
    end
  end

  defp parse_month(_, today), do: first_of_month(today)

  defp parse_view(%{"view" => "agenda"}), do: :agenda
  defp parse_view(%{"view" => "month"}), do: :month
  defp parse_view(%{"month" => month}) when is_binary(month), do: :month
  defp parse_view(_), do: :today

  defp first_of_month(date), do: %{date | day: 1}

  defp month_grid_window(month_first) do
    # Sunday-first grid. Date.day_of_week returns Mon=1..Sun=7.
    # rem(day_of_week, 7) gives Sun=0..Sat=6 — the leading offset.
    offset = rem(Date.day_of_week(month_first), 7)
    grid_start = Date.add(month_first, -offset)
    grid_end = Date.add(grid_start, 41)
    {grid_start, grid_end}
  end

  defp load_entries(user, :today, _grid_start, _grid_end, today, time_zone) do
    {range_start, range_end} = local_day_window(today, time_zone)

    user
    |> calendar_huddlz(range_start, range_end)
    |> Enum.map(&today_entry(&1, user))
  end

  defp load_entries(user, _view_mode, grid_start, grid_end, _today, _time_zone) do
    grid_start_dt = DateTime.new!(grid_start, ~T[00:00:00], "Etc/UTC")
    grid_end_dt = DateTime.new!(grid_end, ~T[23:59:59], "Etc/UTC")

    [:hosting, :attending, :waitlisted]
    |> Enum.flat_map(fn role -> fetch(user, role) end)
    |> merge_entry_roles()
    |> Enum.filter(fn %{huddl: h} ->
      h.starts_at &&
        DateTime.compare(h.starts_at, grid_start_dt) != :lt &&
        DateTime.compare(h.starts_at, grid_end_dt) != :gt
    end)
    |> Enum.sort_by(& &1.huddl.starts_at, DateTime)
  end

  defp device_time_zone(socket) do
    socket
    |> get_connect_params()
    |> then(fn
      %{"timezone" => time_zone} -> valid_time_zone_or_utc(time_zone)
      _ -> "Etc/UTC"
    end)
  end

  defp valid_time_zone_or_utc(time_zone) when is_binary(time_zone) do
    case DateTime.shift_zone(~U[2000-01-01 00:00:00Z], time_zone) do
      {:ok, _datetime} -> time_zone
      {:error, _reason} -> "Etc/UTC"
    end
  end

  defp valid_time_zone_or_utc(_time_zone), do: "Etc/UTC"

  defp today_in(time_zone) do
    Clock.utc_now()
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_date()
  end

  defp local_day_window(today, time_zone) do
    range_start = local_midnight_in_utc(today, time_zone)
    range_end = today |> Date.add(1) |> local_midnight_in_utc(time_zone)
    {range_start, range_end}
  end

  defp local_midnight_in_utc(date, time_zone) do
    date
    |> DateTime.new(~T[00:00:00], time_zone)
    |> local_day_boundary()
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp local_day_boundary({:ok, datetime}), do: datetime
  defp local_day_boundary({:ambiguous, first_datetime, _second_datetime}), do: first_datetime
  defp local_day_boundary({:gap, _just_before, first_datetime}), do: first_datetime

  defp calendar_huddlz(user, range_start, range_end) do
    case Communities.list_calendar_huddlz(range_start, range_end,
           actor: user,
           load: @card_loads
         ) do
      {:ok, huddlz} ->
        huddlz

      {:error, reason} ->
        Logger.warning("CalendarLive Calendar read failed: #{inspect(reason)}")
        []
    end
  end

  defp today_entry(huddl, user) do
    roles =
      MapSet.new()
      |> maybe_add_role(huddl.creator_id == user.id, :hosting)
      |> maybe_add_role(huddl.waitlisted_rsvp_for_actor, :waitlisted)
      |> maybe_add_role(huddl.confirmed_rsvp_for_actor, :attending)

    build_today_entry(huddl, roles)
  end

  defp maybe_add_role(roles, true, role), do: MapSet.put(roles, role)
  defp maybe_add_role(roles, false, _role), do: roles

  defp build_today_entry(huddl, roles) do
    entry = %{huddl: huddl, roles: roles}
    Map.put(entry, :card_status, today_card_status(entry))
  end

  defp today_relationship_label(%{card_status: nil}), do: nil
  defp today_relationship_label(%{card_status: status}), do: status.label

  defp today_relationship_variant(%{card_status: nil}), do: :default
  defp today_relationship_variant(%{card_status: status}), do: status.variant

  defp today_card_status(%{huddl: %{status: status}} = entry) do
    case HuddlStatus.contextual_override(status) do
      nil -> today_relationship_status(entry, status)
      presentation -> struct!(EntryStatus, presentation)
    end
  end

  defp today_relationship_status(entry, :completed), do: past_status(entry)
  defp today_relationship_status(entry, _status), do: relationship_status(entry)

  defp primary_relationship(roles) do
    cond do
      MapSet.member?(roles, :hosting) -> :hosting
      MapSet.member?(roles, :waitlisted) -> :waitlisted
      MapSet.member?(roles, :attending) -> :attending
      true -> nil
    end
  end

  defp fetch(user, role) do
    case Communities.search_huddlz(
           nil,
           :all,
           nil,
           nil,
           nil,
           nil,
           role,
           :soonest,
           actor: user,
           page: false,
           load: @card_loads
         ) do
      {:ok, huddls} when is_list(huddls) ->
        Enum.map(huddls, &%{huddl: &1, role: role})

      {:error, reason} ->
        Logger.warning("CalendarLive search failed (#{role}): #{inspect(reason)}")
        []
    end
  end

  defp merge_entry_roles(entries) do
    entries
    |> Enum.group_by(& &1.huddl.id)
    |> Enum.map(fn {_id, [%{huddl: huddl} | _] = matches} ->
      %{huddl: huddl, roles: MapSet.new(matches, & &1.role)}
    end)
  end

  defp group_by_day(entries) do
    Enum.group_by(entries, fn %{huddl: %{starts_at: dt}} -> DateTime.to_date(dt) end)
  end

  defp in_focus_month?(%{starts_at: %DateTime{} = dt}, %Date{year: y, month: m}) do
    date = DateTime.to_date(dt)
    date.year == y && date.month == m
  end

  defp in_focus_month?(_, _), do: false

  defp shift_month(date, delta) do
    total = date.year * 12 + (date.month - 1) + delta
    Date.new!(Integer.floor_div(total, 12), Integer.mod(total, 12) + 1, 1)
  end

  defp month_path(month, view) do
    base = month_param(month)
    view_str = if view in [:month, :agenda], do: Atom.to_string(view)

    cond do
      base && view_str -> ~p"/calendar?#{[month: base, view: view_str]}"
      base -> ~p"/calendar?#{[month: base]}"
      view_str -> ~p"/calendar?#{[view: view_str]}"
      true -> ~p"/calendar"
    end
  end

  defp month_param(month) do
    today_first = first_of_month(Date.utc_today())
    if Date.compare(month, today_first) == :eq, do: nil, else: format_month_param(month)
  end

  defp format_month_param(%Date{year: y, month: m}) do
    "#{y}-#{String.pad_leading(to_string(m), 2, "0")}"
  end

  defp format_month(%Date{year: y, month: m}) do
    {:ok, date} = Date.new(y, m, 1)
    Calendar.strftime(date, "%B %Y")
  end

  defp format_count(0), do: "0 huddlz"
  defp format_count(1), do: "1 huddl"
  defp format_count(n), do: "#{n} huddlz"

  defp days_in_grid(grid_start) do
    Enum.map(0..41, &Date.add(grid_start, &1))
  end

  defp weeks_in_grid(grid_start) do
    grid_start
    |> days_in_grid()
    |> Enum.chunk_every(7)
  end

  defp day_in_focus?(%Date{} = day, %Date{year: y, month: m}),
    do: day.year == y and day.month == m

  defp format_full_date(%Date{} = day), do: Calendar.strftime(day, "%A, %B %-d, %Y")

  defp day_accessible_label(day, focus_month, today) do
    [
      format_full_date(day),
      Date.compare(day, today) == :eq && "today",
      !day_in_focus?(day, focus_month) && "outside the selected month"
    ]
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.join(", ")
  end

  defp pill_class_for(entry, day, focus_month, today) do
    base = base_pill_class(entry, today)
    if day_in_focus?(day, focus_month), do: base, else: base <> " out-of-month-pill"
  end

  defp base_pill_class(entry, today) do
    case entry_status(entry, today).variant do
      :muted -> "cal-pill past"
      :warn -> "cal-pill tentative waitlisted"
      :magenta -> "cal-pill hosting"
      :cyan -> "cal-pill going"
    end
  end

  defp format_pill_time(%{huddl: %{starts_at: starts_at}}),
    do: Calendar.strftime(starts_at, "%-I:%M %p")

  defp format_pill_tooltip(%{huddl: %{title: title}} = entry, today) do
    "#{format_pill_time(entry)} · #{title} · #{entry_status(entry, today).label}"
  end

  defp format_calendar_link_label(entry, today) do
    date_and_time = Calendar.strftime(entry.huddl.starts_at, "%A, %B %-d, %Y at %-I:%M %p")
    "#{entry.huddl.title}, #{calendar_status_label(entry, today)}, #{date_and_time}"
  end

  defp calendar_status_label(%{huddl: %{starts_at: starts_at, status: status}} = entry, today) do
    case HuddlStatus.contextual_override(status) do
      %{label: label} ->
        label

      nil ->
        case Date.compare(DateTime.to_date(starts_at), today) do
          :lt -> past_relationship_label(entry)
          _ -> relationship_status(entry).label
        end
    end
  end

  defp huddl_path(%{huddl: %{id: id, group: %{slug: slug}}}),
    do: ~p"/groups/#{slug}/huddlz/#{id}"

  defp agenda_entries(entries, focus_month) do
    entries
    |> Enum.filter(fn %{huddl: h} -> in_focus_month?(h, focus_month) end)
    |> Enum.sort_by(fn %{huddl: %{starts_at: dt}} -> dt end, DateTime)
  end

  defp entry_status(%{huddl: %{status: status}} = entry, %Date{} = today) do
    case HuddlStatus.contextual_override(status) do
      nil -> timed_entry_status(entry, today)
      presentation -> struct!(EntryStatus, presentation)
    end
  end

  defp timed_entry_status(%{huddl: %{starts_at: starts_at}} = entry, today) do
    case Date.compare(DateTime.to_date(starts_at), today) do
      :lt -> past_status(entry)
      _ -> relationship_status(entry)
    end
  end

  defp relationship_status(%{roles: roles}) do
    case primary_relationship(roles) do
      :hosting ->
        %EntryStatus{key: "hosting", label: "Hosting", variant: :magenta, rank: 1}

      :waitlisted ->
        %EntryStatus{key: "waitlist", label: "Waitlisted", variant: :warn, rank: 2}

      :attending ->
        %EntryStatus{key: "going", label: "Going", variant: :cyan, rank: 3}

      nil ->
        nil
    end
  end

  defp past_status(%{roles: roles}) do
    case primary_relationship(roles) do
      :hosting ->
        %EntryStatus{
          key: "past-hosting",
          label: "Hosting · Past",
          variant: :muted,
          rank: 4
        }

      :waitlisted ->
        %EntryStatus{
          key: "past-waitlisted",
          label: "Waitlisted · Past",
          variant: :muted,
          rank: 5
        }

      :attending ->
        %EntryStatus{
          key: "past-attended",
          label: "Attended · Past",
          variant: :muted,
          rank: 6
        }

      nil ->
        nil
    end
  end

  defp past_relationship_label(%{roles: roles}) do
    case primary_relationship(roles) do
      :hosting -> "Hosted, past"
      :waitlisted -> "Waitlisted, past"
      :attending -> "Attended, past"
      nil -> nil
    end
  end

  defp legend_items(entries, focus_month, view_mode, today) do
    entries
    |> visible_entries(focus_month, view_mode)
    |> Enum.map(&entry_status(&1, today))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.key)
    |> Enum.sort_by(& &1.rank)
  end

  defp visible_entries(entries, _focus_month, :month), do: entries
  defp visible_entries(entries, focus_month, :agenda), do: agenda_entries(entries, focus_month)
  defp visible_entries(entries, _focus_month, :today), do: entries

  defp legend_swatch_class(%{variant: variant}), do: ["cal-legend-swatch", variant]

  defp format_agenda_when(%DateTime{} = dt) do
    Calendar.strftime(dt, "%a %b %-d · %-I:%M %p")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="calendar"
    >
      <div class="page-head">
        <div>
          <h1>Calendar</h1>
          <p>
            Your huddlz for today, in chronological order.
          </p>
        </div>
      </div>

      <div id="calendar-time-zone" phx-hook="CalendarTimeZone"></div>

      <div class="cal-toolbar">
        <div class="cal-nav">
          <.link
            patch={month_path(shift_month(@focus_month, -1), @view_mode)}
            class="cal-nav-btn"
            aria-label="Previous month"
          >
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="m15 18-6-6 6-6" />
            </svg>
          </.link>
          <.link patch={month_path(first_of_month(@today), @view_mode)} class="cal-nav-today">
            Today
          </.link>
          <.link
            patch={month_path(shift_month(@focus_month, 1), @view_mode)}
            class="cal-nav-btn"
            aria-label="Next month"
          >
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="m9 6 6 6-6 6" />
            </svg>
          </.link>
        </div>

        <div class="cal-month-title">
          <span class="cal-month-name">{format_month(@focus_month)}</span>
          <span class="cal-month-count">({format_count(@in_month_count)})</span>
        </div>

        <div class="cal-view-tabs">
          <.link
            id="calendar-view-today"
            patch={~p"/calendar"}
            class={["scope-tab", @view_mode == :today && "is-active"]}
            aria-current={if @view_mode == :today, do: "page"}
          >
            Today
          </.link>
          <.link
            id="calendar-view-month"
            patch={month_path(@focus_month, :month)}
            class={["scope-tab", @view_mode == :month && "is-active"]}
            aria-current={if @view_mode == :month, do: "page"}
          >
            Month
          </.link>
          <.link
            id="calendar-view-agenda"
            patch={month_path(@focus_month, :agenda)}
            class={["scope-tab", @view_mode == :agenda && "is-active"]}
            aria-current={if @view_mode == :agenda, do: "page"}
          >
            Agenda
          </.link>
        </div>
      </div>

      <%= case @view_mode do %>
        <% :today -> %>
          <.today_view today_empty?={@today_empty?} entries={@streams.today_entries} />
        <% :month -> %>
          <.month_grid
            entries={@entries}
            focus_month={@focus_month}
            grid_start={@grid_start}
            entries_by_day={@entries_by_day}
            today={@today}
          />
        <% :agenda -> %>
          <.agenda_view entries={@entries} focus_month={@focus_month} today={@today} />
      <% end %>

      <div
        :if={!@legend_empty?}
        id="calendar-legend"
        class="cal-legend"
        aria-label="Calendar statuses"
        phx-update="stream"
      >
        <span
          :for={{id, item} <- @streams.legend_items}
          id={id}
          class="cal-legend-item"
          data-status={item.key}
        >
          <span class={legend_swatch_class(item)} aria-hidden="true"></span>
          {item.label}
        </span>
      </div>
    </Layouts.app>
    """
  end

  attr :today_empty?, :boolean, required: true
  attr :entries, :any, required: true

  defp today_view(assigns) do
    ~H"""
    <section id="calendar-today" aria-labelledby="calendar-today-title">
      <h2 id="calendar-today-title" class="sr-only">Today</h2>
      <div id="calendar-today-list" class="grid" phx-update="stream">
        <p :if={@today_empty?} id="calendar-today-empty" class="empty-state muted">
          Nothing on your calendar today.
        </p>
        <.shared_huddl_card
          :for={{id, entry} <- @entries}
          id={id}
          huddl={entry.huddl}
          relationship_label={today_relationship_label(entry)}
          relationship_variant={today_relationship_variant(entry)}
          relationship_testid="calendar-relationship"
        />
      </div>
    </section>
    """
  end

  attr :focus_month, Date, required: true
  attr :grid_start, Date, required: true
  attr :entries, :list, required: true
  attr :entries_by_day, :map, required: true
  attr :today, Date, required: true

  defp month_grid(assigns) do
    ~H"""
    <div>
      <div class="panel cal-calendar-panel" style="padding:0">
        <table id="month-calendar" class="cal-calendar">
          <caption class="sr-only">
            Month calendar for {format_month(@focus_month)}
          </caption>
          <thead>
            <tr>
              <th :for={{short, full} <- weekday_names()} scope="col" class="cal-day-name">
                <abbr title={full}>{short}</abbr>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={week <- weeks_in_grid(@grid_start)}>
              <td
                :for={day <- week}
                class={cell_class(day, @focus_month)}
                aria-label={day_accessible_label(day, @focus_month, @today)}
                aria-current={if Date.compare(day, @today) == :eq, do: "date"}
              >
                <div class="cal-cell-content">
                  <div class="cal-day-heading" aria-hidden="true">
                    <time datetime={Date.to_iso8601(day)} class={day_num_class(day, @today)}>
                      {day.day}
                    </time>
                    <span :if={Date.compare(day, @today) == :eq} class="cal-day-context">
                      Today
                    </span>
                    <span :if={!day_in_focus?(day, @focus_month)} class="cal-day-context">
                      {Calendar.strftime(day, "%b")}
                    </span>
                  </div>
                  <.link
                    :for={entry <- Map.get(@entries_by_day, day, [])}
                    id={"calendar-entry-#{entry.huddl.id}"}
                    navigate={huddl_path(entry)}
                    class={pill_class_for(entry, day, @focus_month, @today)}
                    aria-label={format_calendar_link_label(entry, @today)}
                    aria-describedby={"calendar-entry-tooltip-#{entry.huddl.id}"}
                    data-status={entry_status(entry, @today).key}
                  >
                    <span class="cal-pill-primary" aria-hidden="true">
                      <time
                        class="cal-pill-time"
                        datetime={DateTime.to_iso8601(entry.huddl.starts_at)}
                      >
                        {format_pill_time(entry)}
                      </time>
                      <span class="cal-pill-separator">·</span>
                      <span class="cal-pill-title">{entry.huddl.title}</span>
                    </span>
                    <span class="cal-pill-status" aria-hidden="true">
                      {entry_status(entry, @today).label}
                    </span>
                    <span
                      id={"calendar-entry-tooltip-#{entry.huddl.id}"}
                      class="cal-pill-tooltip"
                      role="tooltip"
                    >
                      {format_pill_tooltip(entry, @today)}
                    </span>
                  </.link>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <section
        :if={@entries != []}
        id="calendar-touch-agenda"
        class="cal-touch-agenda"
        aria-labelledby="calendar-touch-agenda-title"
      >
        <div class="cal-touch-agenda-heading">
          <p class="cal-touch-agenda-kicker">Calendar details</p>
          <h2 id="calendar-touch-agenda-title">Huddlz shown above</h2>
        </div>
        <div class="cal-touch-agenda-list">
          <.link
            :for={entry <- @entries}
            id={"calendar-touch-entry-#{entry.huddl.id}"}
            navigate={huddl_path(entry)}
            class="cal-touch-entry"
            data-status={entry_status(entry, @today).key}
          >
            <time datetime={DateTime.to_iso8601(entry.huddl.starts_at)}>
              {format_agenda_when(entry.huddl.starts_at)}
            </time>
            <span class="cal-touch-entry-title">{entry.huddl.title}</span>
            <span class="cal-touch-entry-status">{entry_status(entry, @today).label}</span>
          </.link>
        </div>
      </section>
    </div>
    """
  end

  defp weekday_names do
    [
      {"Sun", "Sunday"},
      {"Mon", "Monday"},
      {"Tue", "Tuesday"},
      {"Wed", "Wednesday"},
      {"Thu", "Thursday"},
      {"Fri", "Friday"},
      {"Sat", "Saturday"}
    ]
  end

  defp cell_class(day, focus_month) do
    if day_in_focus?(day, focus_month), do: "cal-cell", else: "cal-cell out-of-month"
  end

  defp day_num_class(day, today) do
    if Date.compare(day, today) == :eq, do: "cal-day-num is-today", else: "cal-day-num"
  end

  attr :entries, :list, required: true
  attr :focus_month, Date, required: true
  attr :today, Date, required: true

  defp agenda_view(assigns) do
    sorted = agenda_entries(assigns.entries, assigns.focus_month)
    assigns = assign(assigns, :sorted, sorted)

    ~H"""
    <%= if @sorted == [] do %>
      <p class="muted">Nothing on the calendar this month.</p>
    <% else %>
      <div class="panel" style="padding:0">
        <div class="row-list" style="padding:6px 20px">
          <.link
            :for={entry <- @sorted}
            id={"calendar-entry-#{entry.huddl.id}"}
            navigate={huddl_path(entry)}
            class="row"
            style="grid-template-columns: 200px 1fr auto; text-decoration: none"
          >
            <span class="meta">{format_agenda_when(entry.huddl.starts_at)}</span>
            <span class="row-title">{entry.huddl.title}</span>
            <.pill
              variant={entry_status(entry, @today).variant}
              class="cal-entry-status"
              data-status={entry_status(entry, @today).key}
            >
              {entry_status(entry, @today).label}
            </.pill>
          </.link>
        </div>
      </div>
    <% end %>
    """
  end
end
