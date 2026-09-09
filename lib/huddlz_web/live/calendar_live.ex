defmodule HuddlzWeb.CalendarLive do
  @moduledoc """
  LiveView at `/calendar`. Personal calendar of huddlz the signed-in user
  is hosting, attending, or watching from the waitlist. Agenda by default
  with a month grid behind `?view=month`; `?month=YYYY-MM` drives the grid.
  The agenda ignores the month: it starts at today and runs
  forward through the next few days that have huddlz, one entry per huddl,
  leaving the past to the month grid. `?scope=groups` widens both views
  from the person's own RSVPs to everything their groups have scheduled.
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

  @card_loads [:status, :group, :display_image_url]

  # How many days with huddlz the agenda shows after today before pointing
  # at the month view for the rest.
  @agenda_days 7

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    time_zone = BrowserTimeZone.for_socket(socket)
    today = DateTime.now!(time_zone) |> DateTime.to_date()

    {:ok,
     socket
     |> assign(:page_title, "Calendar")
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

    scope = parse_scope(params["scope"])
    today = socket.assigns.today
    own = load_entries(user, socket.assigns.time_zone)
    group_extras = load_group_extras(user, socket.assigns.time_zone, own, today)
    all = if scope == :groups, do: merge_entries(own, group_extras), else: own
    entries = grid_entries(all, grid_start, grid_end, socket.assigns.time_zone)
    {agenda_days, agenda_more} = agenda_window(all, today)
    agenda_entries = Enum.flat_map(agenda_days, & &1.entries)

    entries_by_day = group_by_day(entries)
    in_month_count = Enum.count(entries, &in_focus_month?(&1, focus_month))
    visible = if view_mode == :month, do: entries, else: agenda_entries
    legend_items = legend_items(visible, today)

    {:noreply,
     socket
     |> assign(:focus_month, focus_month)
     |> assign(:view_mode, view_mode)
     |> assign(:scope, scope)
     |> assign(:counts, scope_counts(own, group_extras, today))
     |> assign(:grid_start, grid_start)
     |> assign(:grid_end, grid_end)
     |> assign(:entries, entries)
     |> assign(:first_run?, all == [])
     |> assign(:entries_by_day, entries_by_day)
     |> assign(:in_month_count, in_month_count)
     |> assign(:agenda_days, agenda_days)
     |> assign(:agenda_more, agenda_more)
     |> assign(:agenda_count, length(agenda_entries))
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

  defp parse_view("month"), do: :month
  defp parse_view(_), do: :agenda

  defp parse_scope("groups"), do: :groups
  defp parse_scope(_), do: :mine

  defp first_of_month(date), do: %{date | day: 1}

  defp month_grid_window(month_first) do
    # Sunday-first grid. Date.day_of_week returns Mon=1..Sun=7.
    # rem(day_of_week, 7) gives Sun=0..Sat=6 — the leading offset.
    offset = rem(Date.day_of_week(month_first), 7)
    grid_start = Date.add(month_first, -offset)
    grid_end = Date.add(grid_start, 41)
    {grid_start, grid_end}
  end

  # Every huddl the person hosts, attends or waits on, in calendar time,
  # soonest first. The search already fetches them all, so the month grid,
  # the agenda and the first-run check all read from this one list.
  defp load_entries(user, time_zone) do
    [:hosting, :attending, :waitlisted]
    |> Enum.flat_map(fn role -> fetch(user, role) end)
    |> merge_entry_roles()
    |> Enum.filter(& &1.huddl.starts_at)
    |> Enum.map(&put_calendar_time(&1, time_zone))
    |> Enum.sort_by(& &1.huddl.starts_at, DateTime)
  end

  # Upcoming huddlz from groups the person owns or has joined that they have
  # not responded to. Their own entries win on overlap, and the past is left
  # out: a huddl they did not attend is not a calendar fact.
  defp load_group_extras(user, time_zone, own, today) do
    own_ids = MapSet.new(own, & &1.huddl.id)

    user
    |> fetch(:member)
    |> Enum.reject(&MapSet.member?(own_ids, &1.huddl.id))
    |> Enum.filter(& &1.huddl.starts_at)
    |> Enum.map(&%{huddl: &1.huddl, roles: MapSet.new([:member])})
    |> Enum.map(&put_calendar_time(&1, time_zone))
    |> Enum.filter(&(Date.compare(&1.calendar_date, today) != :lt))
  end

  defp merge_entries(own, extras) do
    Enum.sort_by(own ++ extras, & &1.huddl.starts_at, DateTime)
  end

  defp scope_counts(own, extras, today) do
    mine = Enum.count(own, &(Date.compare(&1.calendar_date, today) != :lt))
    %{mine: mine, groups: mine + length(extras)}
  end

  defp grid_entries(entries, grid_start, grid_end, time_zone) do
    grid_start_dt = utc_boundary(grid_start, ~T[00:00:00], time_zone)
    grid_end_dt = utc_boundary(grid_end, ~T[23:59:59], time_zone)

    Enum.filter(entries, fn %{huddl: h} ->
      DateTime.compare(h.starts_at, grid_start_dt) != :lt &&
        DateTime.compare(h.starts_at, grid_end_dt) != :gt
    end)
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

  # The calendar's own URL: the month only matters to the month view, the
  # default view and scope are left out, and today's month is the default.
  defp calendar_path(month, view, today, scope) do
    params =
      [
        month: view == :month && month_param(month, today),
        view: view == :month && "month",
        scope: scope == :groups && "groups"
      ]
      |> Enum.filter(fn {_key, value} -> value end)

    if params == [], do: ~p"/calendar", else: ~p"/calendar?#{params}"
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
      :outline -> "cal-pill open"
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

      true ->
        %EntryStatus{key: "open", label: "No RSVP", variant: :outline, rank: 9}
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

  defp legend_items(entries, today) do
    entries
    |> Enum.map(&entry_status(&1, today))
    |> Enum.uniq_by(& &1.key)
    |> Enum.sort_by(& &1.rank)
  end

  defp legend_swatch_class(%{variant: variant}), do: ["cal-legend-swatch", variant]

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
            huddlz you're hosting, attending, or watching from the waitlist. Calendar dates use <strong id="calendar-time-zone">{@time_zone}</strong>.
          </p>
        </div>
      </div>

      <div class="cal-toolbar">
        <%= if @view_mode == :month do %>
          <div class="cal-nav">
            <.link
              patch={calendar_path(shift_month(@focus_month, -1), @view_mode, @today, @scope)}
              class="cal-nav-btn"
              aria-label="Previous month"
            >
              <.icon name="hero-chevron-left" class="size-4" />
            </.link>
            <.link
              patch={calendar_path(first_of_month(@today), @view_mode, @today, @scope)}
              class="cal-nav-today"
            >
              Today
            </.link>
            <.link
              patch={calendar_path(shift_month(@focus_month, 1), @view_mode, @today, @scope)}
              class="cal-nav-btn"
              aria-label="Next month"
            >
              <.icon name="hero-chevron-right" class="size-4" />
            </.link>
          </div>

          <div class="cal-month-title">
            <span class="cal-month-name">{format_month(@focus_month)}</span>
            <span class="cal-month-count">{format_count(@in_month_count)}</span>
          </div>
        <% else %>
          <div class="cal-month-title">
            <span class="cal-month-name">What's next</span>
            <span class="cal-month-count">{format_count(@agenda_count)}</span>
          </div>
        <% end %>

        <div class="cal-view-tabs">
          <.link
            id="calendar-view-agenda"
            patch={calendar_path(@focus_month, :agenda, @today, @scope)}
            class={["scope-tab", @view_mode == :agenda && "is-active"]}
            aria-current={if @view_mode == :agenda, do: "page"}
          >
            Agenda
          </.link>
          <.link
            id="calendar-view-month"
            patch={calendar_path(@focus_month, :month, @today, @scope)}
            class={["scope-tab", @view_mode == :month && "is-active"]}
            aria-current={if @view_mode == :month, do: "page"}
          >
            Month
          </.link>
        </div>
      </div>

      <div class="chip-group cal-scope" aria-label="Whose huddlz to show">
        <.chip
          id="calendar-scope-mine"
          patch={calendar_path(@focus_month, @view_mode, @today, :mine)}
          active={@scope == :mine}
          count={@counts.mine}
        >
          RSVPs
        </.chip>
        <.chip
          id="calendar-scope-groups"
          patch={calendar_path(@focus_month, @view_mode, @today, :groups)}
          active={@scope == :groups}
          count={@counts.groups}
        >
          Groups
        </.chip>
      </div>

      <%= if @view_mode == :month do %>
        <.month_grid
          entries={@entries}
          focus_month={@focus_month}
          grid_start={@grid_start}
          entries_by_day={@entries_by_day}
          today={@today}
        />
        <.first_run_empty :if={@first_run?} />
      <% else %>
        <.agenda_view
          days={@agenda_days}
          more={@agenda_more}
          today={@today}
          scope={@scope}
          first_run?={@first_run?}
        />
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
      <div class="cal-calendar-panel">
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
        <.agenda_list
          id="calendar-touch-agenda-list"
          entry_prefix="calendar-touch-entry"
          days={agenda_days(@entries, @focus_month, @today, anchor_today: false)}
          today={@today}
        />
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

  # The calendar's first run: no huddl in any month. Says what the page
  # holds and offers the action that fills it.
  defp first_run_empty(assigns) do
    ~H"""
    <.empty_state
      id="calendar-first-run"
      icon="hero-calendar"
      title="Your calendar is empty"
      data-first-run
    >
      Huddlz you RSVP to show up here, in their own time zone.
      <:action>
        <.button variant={:primary} navigate={~p"/discover"}>
          <.icon name="hero-magnifying-glass" class="size-4" /> Find a huddl
        </.button>
      </:action>
    </.empty_state>
    """
  end

  attr :days, :list, required: true
  attr :more, :any, required: true, doc: "first day with huddlz beyond the window, or nil"
  attr :today, Date, required: true
  attr :scope, :atom, required: true
  attr :first_run?, :boolean, default: false

  defp agenda_view(assigns) do
    ~H"""
    <%= if @first_run? do %>
      <.first_run_empty />
    <% else %>
      <%= if Enum.all?(@days, &(&1.entries == [])) do %>
        <.empty_state id="calendar-agenda-empty" icon="hero-calendar" title="Nothing coming up">
          Your next RSVP will land here.
          <:action>
            <.button variant={:secondary} navigate={~p"/discover"}>Browse huddlz</.button>
          </:action>
        </.empty_state>
      <% else %>
        <.agenda_list
          id="calendar-agenda"
          entry_prefix="calendar-entry"
          days={@days}
          today={@today}
        />
        <p :if={@more} id="calendar-agenda-more" class="cal-agenda-more">
          More after {Calendar.strftime(List.last(@days).date, "%A, %B %-d")}.
          <.link patch={calendar_path(first_of_month(@more), :month, @today, @scope)}>
            Open {format_month(@more)} in the month view
          </.link>
        </p>
      <% end %>
    <% end %>
    """
  end

  # The agenda list: one group per day with a date rail on the left and
  # the day's huddlz on the right, in time order. The next row is the next
  # thing, so an empty today says no more than that.
  attr :id, :string, required: true
  attr :entry_prefix, :string, required: true
  attr :days, :list, required: true
  attr :today, Date, required: true

  defp agenda_list(assigns) do
    ~H"""
    <div id={@id} class="cal-agenda">
      <div
        :for={day <- @days}
        id={"#{@id}-day-#{Date.to_iso8601(day.date)}"}
        class="cal-agenda-day"
        data-today={day.today? || nil}
        data-past={day.past? || nil}
      >
        <div class="cal-agenda-rail">
          <span class="cal-agenda-weekday" aria-hidden="true">
            {Calendar.strftime(day.date, "%a")}
          </span>
          <time
            datetime={Date.to_iso8601(day.date)}
            class={["cal-agenda-daynum", day.today? && "is-today"]}
            aria-label={format_full_date(day.date)}
          >
            {day.date.day}
          </time>
          <span :if={day.today?} class="cal-agenda-day-context">Today</span>
          <span :if={day.other_month?} class="cal-agenda-day-context">
            {Calendar.strftime(day.date, "%b")}
          </span>
        </div>
        <div class="cal-agenda-entries">
          <.agenda_entry
            :for={entry <- day.entries}
            id={"#{@entry_prefix}-#{entry.huddl.id}"}
            entry={entry}
            today={@today}
          />
          <p :if={day.entries == []} class="cal-agenda-quiet">Nothing today.</p>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :entry, :map, required: true
  attr :today, Date, required: true

  defp agenda_entry(assigns) do
    assigns = assign(assigns, :status, entry_status(assigns.entry, assigns.today))

    ~H"""
    <.link
      id={@id}
      navigate={huddl_path(@entry)}
      class="cal-agenda-entry"
      data-status={@status.key}
    >
      <div class="cal-agenda-thumb">
        <%= if @entry.huddl.display_image_url do %>
          <.cover_image
            id={"#{@id}-cover"}
            class="cal-agenda-thumb-img"
            image_url={@entry.huddl.display_image_url}
          />
        <% else %>
          <.cover_fallback name={@entry.huddl.group.name} />
        <% end %>
      </div>
      <div class="cal-agenda-body">
        <time class="cal-agenda-time" datetime={DateTime.to_iso8601(@entry.huddl.starts_at)}>
          {format_pill_time(@entry)}
        </time>
        <span class="cal-agenda-title">{@entry.huddl.title}</span>
        <span class="cal-agenda-meta">
          <span>{@entry.huddl.group.name}</span>
          <span class="dot" aria-hidden="true"></span>
          <span>{place_label(@entry.huddl)}</span>
        </span>
      </div>
      <div class="cal-agenda-side">
        <.pill
          :if={@status.variant != :outline}
          variant={@status.variant}
          class="cal-entry-status"
          data-status={@status.key}
        >
          {@status.label}
        </.pill>
        <span :if={countdown?(@status)} class="cal-agenda-relative">
          {HuddlCardHelpers.relative_time(@entry.huddl.starts_at)}
        </span>
      </div>
    </.link>
    """
  end

  # The agenda window: today, then the next @agenda_days days that have
  # huddlz, whatever month they fall in. Returns the day groups and the
  # first day with huddlz beyond the window, if any.
  defp agenda_window(entries, today) do
    upcoming = Enum.filter(entries, &(Date.compare(&1.calendar_date, today) != :lt))
    dates = upcoming |> Enum.map(& &1.calendar_date) |> Enum.uniq()
    {shown, rest} = Enum.split(dates, @agenda_days)
    shown = MapSet.new(shown)
    windowed = Enum.filter(upcoming, &MapSet.member?(shown, &1.calendar_date))

    {agenda_days(windowed, first_of_month(today), today, anchor_today: true), List.first(rest)}
  end

  # Groups entries by calendar day, in date order. With `anchor_today: true`
  # the list always gets a row for today, with or without a huddl on it, so
  # it reads as today, then what is next. Days outside `reference_month`
  # name their month on the rail.
  defp agenda_days(entries, reference_month, today, anchor_today: anchor?) do
    grouped = Enum.group_by(entries, & &1.calendar_date)

    dates =
      if anchor?,
        do: Enum.uniq([today | Map.keys(grouped)]),
        else: Map.keys(grouped)

    dates
    |> Enum.sort(Date)
    |> Enum.map(fn date ->
      %{
        date: date,
        entries: Map.get(grouped, date, []),
        today?: Date.compare(date, today) == :eq,
        past?: Date.compare(date, today) == :lt,
        other_month?: !day_in_focus?(date, reference_month)
      }
    end)
  end

  # A countdown only makes sense for something still going ahead: not for
  # the past, and not for a cancelled huddl.
  defp countdown?(%EntryStatus{variant: :muted}), do: false
  defp countdown?(%EntryStatus{key: "cancelled"}), do: false
  defp countdown?(_status), do: true

  defp place_label(%{event_type: :virtual}), do: "Online"

  defp place_label(%{physical_location: place}) when is_binary(place) and place != "",
    do: place

  defp place_label(%{event_type: type}), do: HuddlCardHelpers.tag_label(type)
end
