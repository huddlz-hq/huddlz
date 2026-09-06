defmodule HuddlzWeb.CalendarLive do
  @moduledoc """
  LiveView at `/calendar`. Personal calendar of huddlz the signed-in user
  is hosting, attending, or watching from the waitlist. Month grid by
  default with an agenda toggle; `?month=YYYY-MM` and `?view=month|agenda`
  drive state.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.HuddlStatus
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.BrowserTimeZone
  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers
  require Logger

  defmodule EntryStatus do
    @moduledoc false

    @enforce_keys [:key, :label, :variant, :rank]
    defstruct [:key, :label, :variant, :rank]
  end

  @card_loads [:status, :group]

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    time_zone = BrowserTimeZone.for_socket(socket)
    today = DateTime.now!(time_zone) |> DateTime.to_date()

    {:ok,
     socket
     |> assign(:page_title, "My calendar")
     |> assign(:time_zone, time_zone)
     |> assign(:today, today)
     |> stream_configure(:legend_items, dom_id: &"calendar-legend-item-#{&1.key}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    focus_month = parse_month(params["month"], socket.assigns.today)
    view_mode = parse_view(params["view"])
    {grid_start, grid_end} = month_grid_window(focus_month)
    user = socket.assigns.current_user

    entries =
      user
      |> load_entries(grid_start, grid_end, socket.assigns.time_zone)
      |> Enum.map(&put_calendar_time(&1, socket.assigns.time_zone))

    entries_by_day = group_by_day(entries)
    in_month_count = Enum.count(entries, &in_focus_month?(&1, focus_month))
    legend_items = legend_items(entries, focus_month, view_mode, socket.assigns.today)

    {:noreply,
     socket
     |> assign(:focus_month, focus_month)
     |> assign(:view_mode, view_mode)
     |> assign(:grid_start, grid_start)
     |> assign(:grid_end, grid_end)
     |> assign(:entries, entries)
     |> assign(:entries_by_day, entries_by_day)
     |> assign(:in_month_count, in_month_count)
     |> assign(:legend_empty?, legend_items == [])
     |> stream(:legend_items, legend_items, reset: true)}
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

  defp parse_view("agenda"), do: :agenda
  defp parse_view(_), do: :month

  defp first_of_month(date), do: %{date | day: 1}

  defp month_grid_window(month_first) do
    # Sunday-first grid. Date.day_of_week returns Mon=1..Sun=7.
    # rem(day_of_week, 7) gives Sun=0..Sat=6 — the leading offset.
    offset = rem(Date.day_of_week(month_first), 7)
    grid_start = Date.add(month_first, -offset)
    grid_end = Date.add(grid_start, 41)
    {grid_start, grid_end}
  end

  defp load_entries(user, grid_start, grid_end, time_zone) do
    grid_start_dt = utc_boundary(grid_start, ~T[00:00:00], time_zone)
    grid_end_dt = utc_boundary(grid_end, ~T[23:59:59], time_zone)

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

  defp put_calendar_time(entry, time_zone) do
    datetime = DateTime.shift_zone!(entry.huddl.starts_at, time_zone)
    Map.merge(entry, %{calendar_starts_at: datetime, calendar_date: DateTime.to_date(datetime)})
  end

  defp group_by_day(entries) do
    Enum.group_by(entries, & &1.calendar_date)
  end

  defp in_focus_month?(%{calendar_date: date}, %Date{year: y, month: m}) do
    date.year == y && date.month == m
  end

  defp in_focus_month?(_, _), do: false

  defp utc_boundary(date, time, time_zone) do
    date
    |> DateTime.new!(time, time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp shift_month(date, delta) do
    total = date.year * 12 + (date.month - 1) + delta
    Date.new!(Integer.floor_div(total, 12), Integer.mod(total, 12) + 1, 1)
  end

  defp month_path(month, view, today) do
    base = month_param(month, today)
    view_str = if view == :agenda, do: "agenda"

    cond do
      base && view_str -> ~p"/calendar?#{[month: base, view: view_str]}"
      base -> ~p"/calendar?#{[month: base]}"
      view_str -> ~p"/calendar?#{[view: view_str]}"
      true -> ~p"/calendar"
    end
  end

  defp month_param(month, today) do
    today_first = first_of_month(today)
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

  defp format_pill_time(%{huddl: huddl}) do
    local = HuddlCardHelpers.local_starts_at(huddl)
    Calendar.strftime(local, "%-I:%M %p") <> " " <> local.zone_abbr
  end

  defp format_pill_tooltip(%{huddl: %{title: title}} = entry, today) do
    "#{format_pill_time(entry)} · #{title} · #{entry_status(entry, today).label}"
  end

  defp format_calendar_link_label(entry, today) do
    local = HuddlCardHelpers.local_starts_at(entry.huddl)
    date_and_time = Calendar.strftime(local, "%A, %B %-d, %Y at %-I:%M %p %Z")
    "#{entry.huddl.title}, #{calendar_status_label(entry, today)}, #{date_and_time}"
  end

  defp calendar_status_label(%{huddl: %{status: status}} = entry, today) do
    case HuddlStatus.contextual_override(status) do
      %{label: label} ->
        label

      nil ->
        case Date.compare(entry.calendar_date, today) do
          :lt -> past_relationship_label(entry)
          _ -> relationship_status(entry).label
        end
    end
  end

  defp huddl_path(%{huddl: %{id: id, group: %{slug: slug}}}),
    do: ~p"/groups/#{slug}/huddlz/#{id}"

  defp agenda_entries(entries, focus_month) do
    entries
    |> Enum.filter(&in_focus_month?(&1, focus_month))
    |> Enum.sort_by(fn %{huddl: %{starts_at: dt}} -> dt end, DateTime)
  end

  defp entry_status(%{huddl: %{status: status}} = entry, %Date{} = today) do
    case HuddlStatus.contextual_override(status) do
      nil -> timed_entry_status(entry, today)
      presentation -> struct!(EntryStatus, presentation)
    end
  end

  defp timed_entry_status(entry, today) do
    case Date.compare(entry.calendar_date, today) do
      :lt -> past_status(entry)
      _ -> relationship_status(entry)
    end
  end

  defp relationship_status(%{roles: roles}) do
    hosting? = MapSet.member?(roles, :hosting)
    attending? = MapSet.member?(roles, :attending)
    waitlisted? = MapSet.member?(roles, :waitlisted)

    cond do
      hosting? and attending? ->
        %EntryStatus{
          key: "hosting-going",
          label: "Hosting + Going",
          variant: :magenta,
          rank: 0
        }

      hosting? ->
        %EntryStatus{key: "hosting", label: "Hosting", variant: :magenta, rank: 1}

      waitlisted? ->
        %EntryStatus{key: "waitlist", label: "Waitlist", variant: :warn, rank: 3}

      attending? ->
        %EntryStatus{key: "going", label: "Going", variant: :cyan, rank: 2}
    end
  end

  defp past_status(%{roles: roles}) do
    hosting? = MapSet.member?(roles, :hosting)
    attending? = MapSet.member?(roles, :attending)
    waitlisted? = MapSet.member?(roles, :waitlisted)

    cond do
      hosting? and attending? ->
        %EntryStatus{
          key: "past-hosting-attended",
          label: "Hosting + Attended · Past",
          variant: :muted,
          rank: 4
        }

      hosting? ->
        %EntryStatus{
          key: "past-hosting",
          label: "Hosting · Past",
          variant: :muted,
          rank: 5
        }

      waitlisted? ->
        %EntryStatus{
          key: "past-waitlisted",
          label: "Waitlisted · Past",
          variant: :muted,
          rank: 7
        }

      attending? ->
        %EntryStatus{
          key: "past-attended",
          label: "Attended · Past",
          variant: :muted,
          rank: 6
        }
    end
  end

  defp past_relationship_label(%{roles: roles}) do
    hosting? = MapSet.member?(roles, :hosting)
    attending? = MapSet.member?(roles, :attending)
    waitlisted? = MapSet.member?(roles, :waitlisted)

    cond do
      hosting? and attending? -> "Hosted and attended, past"
      hosting? and waitlisted? -> "Hosted and waitlisted, past"
      hosting? -> "Hosted, past"
      waitlisted? -> "Waitlisted, past"
      attending? -> "Attended, past"
    end
  end

  defp legend_items(entries, focus_month, view_mode, today) do
    entries
    |> visible_entries(focus_month, view_mode)
    |> Enum.map(&entry_status(&1, today))
    |> Enum.uniq_by(& &1.key)
    |> Enum.sort_by(& &1.rank)
  end

  defp visible_entries(entries, _focus_month, :month), do: entries
  defp visible_entries(entries, focus_month, :agenda), do: agenda_entries(entries, focus_month)

  defp legend_swatch_class(%{variant: variant}), do: ["cal-legend-swatch", variant]

  defp format_agenda_when(%{starts_at: %DateTime{}} = huddl) do
    local = HuddlCardHelpers.local_starts_at(huddl)
    Calendar.strftime(local, "%a %b %-d · %-I:%M %p %Z")
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
          <h1>My calendar</h1>
          <p>
            huddlz you're hosting, attending, or watching from the waitlist. Calendar dates use <strong id="calendar-time-zone">{@time_zone}</strong>.
          </p>
        </div>
      </div>

      <div class="cal-toolbar">
        <div class="cal-nav">
          <.link
            patch={month_path(shift_month(@focus_month, -1), @view_mode, @today)}
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
          <.link
            patch={month_path(first_of_month(@today), @view_mode, @today)}
            class="cal-nav-today"
          >
            Today
          </.link>
          <.link
            patch={month_path(shift_month(@focus_month, 1), @view_mode, @today)}
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
            id="calendar-view-month"
            patch={month_path(@focus_month, :month, @today)}
            class={["scope-tab", @view_mode == :month && "is-active"]}
            aria-current={if @view_mode == :month, do: "page"}
          >
            Month
          </.link>
          <.link
            id="calendar-view-agenda"
            patch={month_path(@focus_month, :agenda, @today)}
            class={["scope-tab", @view_mode == :agenda && "is-active"]}
            aria-current={if @view_mode == :agenda, do: "page"}
          >
            Agenda
          </.link>
        </div>
      </div>

      <%= if @view_mode == :month do %>
        <.month_grid
          entries={@entries}
          focus_month={@focus_month}
          grid_start={@grid_start}
          entries_by_day={@entries_by_day}
          today={@today}
        />
      <% else %>
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
              {format_agenda_when(entry.huddl)}
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
            <span class="meta">{format_agenda_when(entry.huddl)}</span>
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
