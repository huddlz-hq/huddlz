defmodule HuddlzWeb.CalendarLive do
  @moduledoc """
  LiveView at `/agenda` and `/calendar`. Personal schedule of huddlz the
  signed-in user is hosting, attending, or watching from the waitlist.
  Three views over the same entries:

    * the agenda, `/agenda`, is the signed-in home page. It ignores the
      month: it starts at today and runs forward through the next few days
      that have huddlz, leaving the past to the calendar;
    * the week, `/calendar` (or `?week=YYYY-MM-DD`), is the same day-by-day
      list for one Sunday-to-Saturday week, every day drawn, any week;
    * the month grid, `/calendar?view=month&month=YYYY-MM`, is the
      overview. A day in it opens as a panel, `?day=YYYY-MM-DD`, listing
      that day's huddlz.

  Every piece of state is in the URL, so closing the panel, the browser's
  back button and returning from a huddl all land on the same view.
  `?scope=groups` widens every view from the person's own RSVPs to
  everything their groups have scheduled. Links to the agenda's old home,
  `/calendar?view=agenda`, are sent on to `/agenda`.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.HuddlStatus
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.BrowserTimeZone
  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers
  alias Phoenix.LiveView.JS
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
     |> assign(:time_zone, time_zone)
     |> assign(:today, today)
     |> stream_configure(:legend_items, dom_id: &"calendar-legend-item-#{&1.key}")}
  end

  @impl true
  def handle_params(
        %{"view" => "agenda"} = params,
        _uri,
        %{assigns: %{live_action: :index}} = socket
      ) do
    {:noreply, push_navigate(socket, to: agenda_path(params["scope"]))}
  end

  def handle_params(params, _uri, socket) do
    today = socket.assigns.today
    view_mode = view_mode(socket.assigns.live_action, params["view"])
    focus_week = parse_week(params["week"], today)

    focus_month =
      if view_mode == :week,
        do: first_of_month(focus_week),
        else: parse_month(params["month"], today)

    focus_week = if view_mode == :week, do: focus_week, else: week_for_month(focus_month, today)
    open_day = parse_day(params["day"])
    {grid_start, grid_end} = month_grid_window(focus_month)
    user = socket.assigns.current_user

    scope = parse_scope(params["scope"])
    own = load_entries(user, socket.assigns.time_zone)
    group_extras = load_group_extras(user, socket.assigns.time_zone, own, today)
    all = if scope == :groups, do: merge_entries(own, group_extras), else: own
    entries = grid_entries(all, grid_start, grid_end, socket.assigns.time_zone)
    {agenda_days, agenda_more} = agenda_window(all, today)
    agenda_entries = Enum.flat_map(agenda_days, & &1.entries)
    week_days = week_days(all, focus_week, today)
    week_entries = Enum.flat_map(week_days, & &1.entries)
    day_entries = if open_day, do: Enum.filter(all, &(&1.calendar_date == open_day)), else: []

    entries_by_day = group_by_day(entries)
    in_month_count = Enum.count(entries, &in_focus_month?(&1, focus_month))

    visible =
      case view_mode do
        :month -> entries
        :week -> week_entries
        :agenda -> agenda_entries
      end

    legend_items = legend_items(visible, today)

    {:noreply,
     socket
     |> assign(:page_title, page_title(view_mode))
     |> assign(:focus_month, focus_month)
     |> assign(:focus_week, focus_week)
     |> assign(:view_mode, view_mode)
     |> assign(:scope, scope)
     |> assign(:nav, %{
       view: view_mode,
       month: focus_month,
       week: focus_week,
       scope: scope,
       today: today
     })
     |> assign(:open_day, open_day)
     |> assign(:day_entries, day_entries)
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
     |> assign(:week_days, week_days)
     |> assign(:week_count, length(week_entries))
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

  defp view_mode(:agenda, _param), do: :agenda
  defp view_mode(:index, "month"), do: :month
  defp view_mode(:index, _param), do: :week

  defp page_title(:agenda), do: "Agenda"
  defp page_title(_view), do: "Calendar"

  defp nav_key(:agenda), do: "agenda"
  defp nav_key(_view), do: "calendar"

  defp agenda_path("groups"), do: ~p"/agenda?scope=groups"
  defp agenda_path(_scope), do: ~p"/agenda"

  # Any date in the week names it; the week runs Sunday to Saturday, like
  # the month grid. Anything unreadable means this week.
  defp parse_week(value, today) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Date.beginning_of_week(date, :sunday)
      _ -> Date.beginning_of_week(today, :sunday)
    end
  end

  defp parse_week(_, today), do: Date.beginning_of_week(today, :sunday)

  defp parse_day(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_day(_), do: nil

  # The week the Week tab opens from a month: this week when today is in
  # that month, otherwise the month's first week.
  defp week_for_month(month_first, today) do
    if day_in_focus?(today, month_first),
      do: Date.beginning_of_week(today, :sunday),
      else: Date.beginning_of_week(month_first, :sunday)
  end

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

  # The page's own URL, from the current state (`@nav`) with anything in
  # `overrides` changed. The agenda has its own path; the month only
  # matters to the month view and the week to the week view; the defaults
  # (this week, this month, own RSVPs, no day open) are left out, so the
  # plain `/calendar` is the week and an open day never outlives a view
  # change.
  defp calendar_path(nav, overrides \\ []) do
    view = Keyword.get(overrides, :view, nav.view)
    month = Keyword.get(overrides, :month, nav.month)
    week = Keyword.get(overrides, :week, nav.week)
    scope = Keyword.get(overrides, :scope, nav.scope)
    day = Keyword.get(overrides, :day)

    params =
      [
        month: view == :month && month_param(month, nav.today),
        week: view == :week && week_param(week, nav.today),
        view: view == :month && "month",
        scope: scope == :groups && "groups",
        day: day && Date.to_iso8601(day)
      ]
      |> Enum.filter(fn {_key, value} -> value end)

    page_path(view, params)
  end

  defp page_path(:agenda, []), do: ~p"/agenda"
  defp page_path(:agenda, params), do: ~p"/agenda?#{params}"
  defp page_path(_view, []), do: ~p"/calendar"
  defp page_path(_view, params), do: ~p"/calendar?#{params}"

  defp month_param(month, today) do
    today_first = first_of_month(today)
    if Date.compare(month, today_first) == :eq, do: nil, else: format_month_param(month)
  end

  defp week_param(week, today) do
    if Date.compare(week, Date.beginning_of_week(today, :sunday)) == :eq,
      do: nil,
      else: Date.to_iso8601(week)
  end

  # "Sep 6 – 12, 2026", naming the second month or year only when it
  # changes across the week.
  defp format_week(%Date{} = start) do
    finish = Date.add(start, 6)

    cond do
      start.year != finish.year ->
        "#{Calendar.strftime(start, "%b %-d, %Y")} – #{Calendar.strftime(finish, "%b %-d, %Y")}"

      start.month != finish.month ->
        "#{Calendar.strftime(start, "%b %-d")} – #{Calendar.strftime(finish, "%b %-d, %Y")}"

      true ->
        "#{Calendar.strftime(start, "%b %-d")} – #{Calendar.strftime(finish, "%-d, %Y")}"
    end
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
      active={nav_key(@view_mode)}
    >
      <div class="page-head">
        <div :if={@view_mode == :agenda}>
          <h1>Agenda</h1>
          <p>
            What's next across the huddlz you're hosting, attending, or watching from the waitlist. Times use <strong id="calendar-time-zone">{@time_zone}</strong>.
          </p>
        </div>
        <div :if={@view_mode != :agenda}>
          <h1>Calendar</h1>
          <p>
            huddlz you're hosting, attending, or watching from the waitlist. Calendar dates use <strong id="calendar-time-zone">{@time_zone}</strong>.
          </p>
        </div>
      </div>

      <div class="cal-toolbar">
        <%= case @view_mode do %>
          <% :month -> %>
            <.period_nav
              previous={calendar_path(@nav, month: shift_month(@focus_month, -1))}
              today={calendar_path(@nav, month: first_of_month(@today))}
              next={calendar_path(@nav, month: shift_month(@focus_month, 1))}
              unit="month"
            />
            <div class="cal-month-title">
              <span class="cal-month-name">{format_month(@focus_month)}</span>
              <span class="cal-month-count">{format_count(@in_month_count)}</span>
            </div>
          <% :week -> %>
            <.period_nav
              previous={calendar_path(@nav, week: Date.add(@focus_week, -7))}
              today={calendar_path(@nav, week: Date.beginning_of_week(@today, :sunday))}
              next={calendar_path(@nav, week: Date.add(@focus_week, 7))}
              unit="week"
            />
            <div class="cal-month-title">
              <span class="cal-month-name">{format_week(@focus_week)}</span>
              <span class="cal-month-count">{format_count(@week_count)}</span>
            </div>
          <% :agenda -> %>
            <div class="cal-month-title">
              <span class="cal-month-name">What's next</span>
              <span class="cal-month-count">{format_count(@agenda_count)}</span>
            </div>
        <% end %>

        <div :if={@view_mode != :agenda} class="cal-view-tabs">
          <.link
            :for={{view, label} <- [week: "Week", month: "Month"]}
            id={"calendar-view-#{view}"}
            patch={calendar_path(@nav, view: view)}
            class={["scope-tab", @view_mode == view && "is-active"]}
            aria-current={if @view_mode == view, do: "page"}
          >
            {label}
          </.link>
        </div>
      </div>

      <div class="chip-group cal-scope" aria-label="Whose huddlz to show">
        <.chip
          id="calendar-scope-mine"
          patch={calendar_path(@nav, scope: :mine)}
          active={@scope == :mine}
          count={@counts.mine}
        >
          RSVPs
        </.chip>
        <.chip
          id="calendar-scope-groups"
          patch={calendar_path(@nav, scope: :groups)}
          active={@scope == :groups}
          count={@counts.groups}
        >
          Groups
        </.chip>
      </div>

      <%= case @view_mode do %>
        <% :month -> %>
          <.month_grid
            entries={@entries}
            focus_month={@focus_month}
            grid_start={@grid_start}
            entries_by_day={@entries_by_day}
            today={@today}
            nav={@nav}
            open_day={@open_day}
          />
          <.first_run_empty :if={@first_run?} />
        <% :week -> %>
          <.week_view days={@week_days} today={@today} first_run?={@first_run?} />
        <% :agenda -> %>
          <.agenda_view
            days={@agenda_days}
            more={@agenda_more}
            today={@today}
            nav={@nav}
            first_run?={@first_run?}
          />
      <% end %>

      <.day_panel
        :if={@open_day}
        day={@open_day}
        entries={@day_entries}
        today={@today}
        nav={@nav}
      />

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

  # Previous / Today / Next for the month and week views. The labels are
  # visually hidden text rather than aria-labels so a test can click them
  # by name the way a person reads them.
  attr :previous, :string, required: true
  attr :today, :string, required: true
  attr :next, :string, required: true
  attr :unit, :string, required: true

  defp period_nav(assigns) do
    ~H"""
    <div class="cal-nav">
      <.link patch={@previous} class="cal-nav-btn">
        <.icon name="hero-chevron-left" class="size-4" />
        <span class="sr-only">Previous {@unit}</span>
      </.link>
      <.link patch={@today} class="cal-nav-today">
        Today
      </.link>
      <.link patch={@next} class="cal-nav-btn">
        <.icon name="hero-chevron-right" class="size-4" />
        <span class="sr-only">Next {@unit}</span>
      </.link>
    </div>
    """
  end

  attr :focus_month, Date, required: true
  attr :grid_start, Date, required: true
  attr :entries, :list, required: true
  attr :entries_by_day, :map, required: true
  attr :today, Date, required: true
  attr :nav, :map, required: true
  attr :open_day, :any, required: true

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
                class={cell_class(day, @focus_month, @open_day)}
                aria-label={day_accessible_label(day, @focus_month, @today)}
                aria-current={if Date.compare(day, @today) == :eq, do: "date"}
              >
                <div class="cal-cell-content">
                  <div class="cal-day-heading">
                    <.link
                      id={"calendar-day-link-#{Date.to_iso8601(day)}"}
                      patch={calendar_path(@nav, day: day)}
                      class={day_num_class(day, @today)}
                      aria-label={"Open " <> format_full_date(day)}
                    >
                      {day.day}
                    </.link>
                    <span
                      :if={Date.compare(day, @today) == :eq}
                      class="cal-day-context"
                      aria-hidden="true"
                    >
                      Today
                    </span>
                    <span
                      :if={!day_in_focus?(day, @focus_month)}
                      class="cal-day-context"
                      aria-hidden="true"
                    >
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

  defp cell_class(day, focus_month, open_day) do
    [
      "cal-cell",
      !day_in_focus?(day, focus_month) && "out-of-month",
      open_day && Date.compare(day, open_day) == :eq && "is-open"
    ]
  end

  defp day_num_class(day, today) do
    if Date.compare(day, today) == :eq, do: "cal-day-num is-today", else: "cal-day-num"
  end

  # The first run: no huddl in any month. Says what the page holds and
  # offers the action that fills it. The agenda is the signed-in home, so
  # its copy speaks of the agenda rather than the calendar.
  attr :agenda?, :boolean, default: false

  defp first_run_empty(assigns) do
    ~H"""
    <.empty_state
      id="calendar-first-run"
      icon="hero-calendar"
      title={if @agenda?, do: "Nothing on your agenda yet", else: "Your calendar is empty"}
      data-first-run
    >
      <%= if @agenda? do %>
        Huddlz you RSVP to show up here, soonest first.
      <% else %>
        Huddlz you RSVP to show up here, in their own time zone.
      <% end %>
      <:action>
        <.button variant={:primary} navigate={~p"/discover"}>
          <.icon name="hero-magnifying-glass" class="size-4" /> Find a huddl
        </.button>
      </:action>
    </.empty_state>
    """
  end

  # One calendar week as the agenda list: every day drawn, empty days as a
  # bare rail row, so the shape of the week reads at a glance.
  attr :days, :list, required: true
  attr :today, Date, required: true
  attr :first_run?, :boolean, default: false

  defp week_view(assigns) do
    ~H"""
    <.agenda_list id="calendar-week" entry_prefix="calendar-entry" days={@days} today={@today} />
    <.first_run_empty :if={@first_run?} />
    """
  end

  # One day's huddlz over the month grid: a side panel on wide screens and
  # a bottom sheet on phones. Everything about it is in the URL (`?day=`),
  # so closing it is a patch, Escape and the scrim do the same, and the
  # browser's back button reopens it after a visit to a huddl.
  attr :day, Date, required: true
  attr :entries, :list, required: true
  attr :today, Date, required: true
  attr :nav, :map, required: true

  defp day_panel(assigns) do
    assigns =
      assigns
      |> assign(:close, calendar_path(assigns.nav))
      |> assign(:return_focus, "#calendar-day-link-#{Date.to_iso8601(assigns.day)}")
      |> assign(:today?, Date.compare(assigns.day, assigns.today) == :eq)

    ~H"""
    <div
      id="calendar-day-layer"
      class="cal-day-layer"
      phx-window-keydown={close_day(@close, @return_focus)}
      phx-key="escape"
      phx-mounted={JS.focus_first(to: "#calendar-day-panel")}
    >
      <div class="cal-day-scrim" phx-click={close_day(@close, @return_focus)} aria-hidden="true">
      </div>
      <.focus_wrap
        id="calendar-day-panel"
        class="cal-day-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="calendar-day-panel-title"
        data-today={@today? || nil}
      >
        <div class="cal-day-head">
          <span class="cal-day-kicker">
            {Calendar.strftime(@day, "%A")}
            <span :if={@today?} class="cal-day-kicker-today">· Today</span>
          </span>
          <h2 id="calendar-day-panel-title" class="cal-agenda-day-title">
            {Calendar.strftime(@day, "%B %-d")}
          </h2>
          <span class="cal-day-count">{format_count(length(@entries))}</span>
          <.link
            id="calendar-day-close"
            patch={@close}
            phx-click={JS.focus(to: @return_focus)}
            class="modal-close"
          >
            <.icon name="hero-x-mark" class="size-5" />
            <span class="sr-only">Close</span>
          </.link>
        </div>
        <div class="cal-day-body">
          <.agenda_entry
            :for={entry <- @entries}
            id={"calendar-day-entry-#{entry.huddl.id}"}
            entry={entry}
            today={@today}
          />
          <p :if={@entries == []} class="cal-agenda-quiet">Nothing on this day.</p>
        </div>
        <div class="cal-day-foot">
          <.link
            id="calendar-day-week"
            patch={calendar_path(@nav, view: :week, week: Date.beginning_of_week(@day, :sunday))}
          >
            Open this week <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  defp close_day(path, return_focus) do
    JS.patch(path) |> JS.focus(to: return_focus)
  end

  attr :days, :list, required: true
  attr :more, :any, required: true, doc: "first day with huddlz beyond the window, or nil"
  attr :today, Date, required: true
  attr :nav, :map, required: true
  attr :first_run?, :boolean, default: false

  defp agenda_view(assigns) do
    ~H"""
    <%= if @first_run? do %>
      <.first_run_empty agenda?={true} />
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
          <.link patch={calendar_path(@nav, view: :month, month: first_of_month(@more))}>
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
        data-blank={day.blank? || nil}
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
          <p :if={day.entries == [] && !day.blank?} class="cal-agenda-quiet">Nothing today.</p>
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
        other_month?: !day_in_focus?(date, reference_month),
        blank?: false
      }
    end)
  end

  # The seven days of the week starting on `week_start`, every one drawn.
  # An empty day that is not today is blank: a rail with nothing beside
  # it. The rail names the month only where it changes mid-week; the
  # toolbar already names the week.
  defp week_days(entries, week_start, today) do
    grouped =
      entries
      |> Enum.filter(&(Date.diff(&1.calendar_date, week_start) in 0..6))
      |> Enum.group_by(& &1.calendar_date)

    Enum.map(0..6, fn offset ->
      date = Date.add(week_start, offset)
      day_entries = Map.get(grouped, date, [])
      today? = Date.compare(date, today) == :eq

      %{
        date: date,
        entries: day_entries,
        today?: today?,
        past?: Date.compare(date, today) == :lt,
        other_month?: offset > 0 && date.day == 1,
        blank?: day_entries == [] && !today?
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
