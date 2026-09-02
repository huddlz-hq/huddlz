defmodule HuddlzWeb.CalendarLive do
  @moduledoc """
  LiveView at `/calendar`. Calendar opens on Day and presents relevant huddlz
  in chronological order. Week follows Sunday-through-Saturday boundaries in
  the Calendar time zone. Month presents a full calendar overview and reveals
  the selected Day's huddlz with the same shared cards.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.TimeZone
  alias HuddlzWeb.HuddlStatus
  alias HuddlzWeb.Layouts
  require Logger

  defmodule EntryStatus do
    @moduledoc false

    @enforce_keys [:key, :label, :variant, :rank]
    defstruct [:key, :label, :variant, :rank]
  end

  defmodule MonthDaySummary do
    @moduledoc false

    defstruct active: [], cancelled_count: 0, overflow_count: 0, accessible_text: nil
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
  @coming_up_limit 3
  @calendar_horizon ~U[9999-12-31 23:59:59Z]
  @month_relationship_presentations %{
    hosting: %{key: "hosting", label: "Hosting", variant: :magenta, rank: 1},
    attending: %{key: "going", label: "Going", variant: :cyan, rank: 2},
    waitlisted: %{key: "waitlisted", label: "Waitlisted", variant: :amber, rank: 3},
    group_opportunity: %{
      key: "group-opportunity",
      label: "Group opportunity",
      variant: :neutral,
      rank: 4
    }
  }
  @month_relationship_order [:hosting, :attending, :waitlisted, :group_opportunity]

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    browser_time_zone = browser_time_zone(socket)
    time_zone = TimeZone.display(socket.assigns.current_user, browser_time_zone)

    automatic_time_zone =
      TimeZone.automatic_display(socket.assigns.current_user, browser_time_zone)

    today = today_in(time_zone)

    {:ok,
     socket
     |> assign(:page_title, "Calendar")
     |> assign(:browser_time_zone, browser_time_zone)
     |> assign(:time_zone, time_zone)
     |> assign(:time_zone_options, TimeZone.options(automatic_time_zone))
     |> assign(:today, today)
     |> stream_configure(:entries, dom_id: &"calendar-huddl-#{&1.huddl.id}")
     |> stream_configure(:coming_up_entries,
       dom_id: &"calendar-coming-up-huddl-#{&1.huddl.id}"
     )
     |> stream_configure(:legend_items, dom_id: &"calendar-legend-item-#{&1.key}")
     |> stream_configure(:month_legend_items,
       dom_id: &"calendar-month-legend-item-#{&1.key}"
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_calendar(socket, params)}
  end

  @impl true
  def handle_event("calendar:set-time-zone", %{"timezone" => time_zone}, socket) do
    {:noreply, refresh_time_zone(socket, browser_time_zone: time_zone)}
  end

  def handle_event("calendar:set-time-zone", _params, socket) do
    {:noreply, refresh_time_zone(socket, browser_time_zone: nil)}
  end

  def handle_event(
        "update_display_time_zone",
        %{"display_time_zone" => selection},
        socket
      ) do
    user = socket.assigns.current_user

    case TimeZone.update_preference(user, selection) do
      {:ok, current_user} ->
        {:noreply,
         socket
         |> assign(:current_user, current_user)
         |> refresh_time_zone()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, TimeZone.preference_error_message(reason))}
    end
  end

  defp refresh_time_zone(socket, opts \\ []) do
    browser_time_zone =
      Keyword.get(opts, :browser_time_zone, socket.assigns.browser_time_zone)

    time_zone = TimeZone.display(socket.assigns.current_user, browser_time_zone)

    automatic_time_zone =
      TimeZone.automatic_display(socket.assigns.current_user, browser_time_zone)

    socket
    |> assign(:browser_time_zone, browser_time_zone)
    |> assign(:time_zone, time_zone)
    |> assign(:time_zone_options, TimeZone.options(automatic_time_zone))
    |> assign(:today, today_in(time_zone))
    |> assign_calendar(socket.assigns.calendar_params)
  end

  defp assign_calendar(socket, params) do
    focus_month = parse_month(params["month"], socket.assigns.today)
    view_mode = parse_view(params)

    selected_date =
      selected_date(view_mode, focus_month, params["date"], socket.assigns.today)

    week_start = week_start(selected_date)
    week_end = Date.add(week_start, 6)
    implicit_current_day? = view_mode == :day and is_nil(params["date"])
    {grid_start, grid_end} = month_grid_window(focus_month)
    user = socket.assigns.current_user

    entries =
      load_entries(user, view_mode, selected_date, socket.assigns.time_zone)

    month_overview_entries =
      load_month_overview_entries(
        user,
        view_mode,
        grid_start,
        grid_end,
        socket.assigns.time_zone
      )

    month_day_summaries =
      build_month_day_summaries(
        month_overview_entries,
        grid_start,
        grid_end,
        socket.assigns.time_zone
      )

    in_month_count =
      Enum.count(
        month_overview_entries,
        &in_focus_month?(&1.huddl, focus_month, socket.assigns.time_zone)
      )

    legend_items = legend_items(entries, socket.assigns.today, socket.assigns.time_zone)
    month_legend_items = month_legend_items(view_mode)

    coming_up_entries =
      load_coming_up_entries(
        user,
        implicit_current_day?,
        entries,
        socket.assigns.today,
        socket.assigns.time_zone
      )

    socket
    |> assign(:calendar_params, params)
    |> assign(:focus_month, focus_month)
    |> assign(:week_start, week_start)
    |> assign(:week_end, week_end)
    |> assign(:selected_date, selected_date)
    |> assign(:current_day?, Date.compare(selected_date, socket.assigns.today) == :eq)
    |> assign(:view_mode, view_mode)
    |> assign(:grid_start, grid_start)
    |> assign(:grid_end, grid_end)
    |> assign(:entries, entries)
    |> assign(:month_day_summaries, month_day_summaries)
    |> assign(:in_month_count, in_month_count)
    |> assign(:entries_empty?, entries == [])
    |> assign(:coming_up_empty?, coming_up_entries == [])
    |> assign(:legend_empty?, legend_items == [])
    |> assign(:month_legend_empty?, month_legend_items == [])
    |> stream(:entries, entries, reset: true)
    |> stream(:coming_up_entries, coming_up_entries, reset: true)
    |> stream(:legend_items, legend_items, reset: true)
    |> stream(:month_legend_items, month_legend_items, reset: true)
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

  defp parse_date(nil, today), do: today

  defp parse_date(value, today) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> today
    end
  end

  defp parse_date(_, today), do: today

  defp selected_date(:month, focus_month, nil, today) do
    if same_month?(focus_month, today), do: today, else: focus_month
  end

  defp selected_date(:month, focus_month, value, today) do
    case parse_date(value, today) do
      %Date{} = date -> if same_month?(focus_month, date), do: date, else: focus_month
    end
  end

  defp selected_date(_view_mode, _focus_month, value, today), do: parse_date(value, today)

  defp parse_view(%{"view" => "day"}), do: :day
  defp parse_view(%{"view" => "week"}), do: :week
  defp parse_view(%{"view" => "month"}), do: :month
  defp parse_view(%{"month" => month}) when is_binary(month), do: :month
  defp parse_view(_), do: :day

  defp first_of_month(date), do: %{date | day: 1}

  defp week_start(date), do: Date.add(date, -rem(Date.day_of_week(date), 7))

  defp month_grid_window(month_first) do
    # Sunday-first grid. Date.day_of_week returns Mon=1..Sun=7.
    # rem(day_of_week, 7) gives Sun=0..Sat=6 — the leading offset.
    offset = rem(Date.day_of_week(month_first), 7)
    grid_start = Date.add(month_first, -offset)
    grid_end = Date.add(grid_start, 41)
    {grid_start, grid_end}
  end

  defp load_entries(user, view_mode, selected_date, time_zone)
       when view_mode in [:day, :month] do
    {range_start, range_end} = local_day_window(selected_date, time_zone)

    user
    |> calendar_huddlz(range_start, range_end)
    |> Enum.map(&day_entry(&1, user))
  end

  defp load_entries(user, :week, selected_date, time_zone) do
    range_start_date = week_start(selected_date)
    range_start = local_midnight_in_utc(range_start_date, time_zone)
    range_end = range_start_date |> Date.add(7) |> local_midnight_in_utc(time_zone)

    user
    |> calendar_huddlz(range_start, range_end)
    |> Enum.map(&day_entry(&1, user))
  end

  defp load_month_overview_entries(user, :month, grid_start, grid_end, time_zone) do
    range_start = local_midnight_in_utc(grid_start, time_zone)
    range_end = grid_end |> Date.add(1) |> local_midnight_in_utc(time_zone)

    user
    |> calendar_huddlz(range_start, range_end)
    |> Enum.map(&day_entry(&1, user))
  end

  defp load_month_overview_entries(_user, _view_mode, _grid_start, _grid_end, _time_zone),
    do: []

  defp load_coming_up_entries(user, true, [], today, time_zone) do
    {_range_start, range_end} = local_day_window(today, time_zone)

    case Communities.list_calendar_huddlz(range_end, @calendar_horizon,
           actor: user,
           load: @card_loads,
           query: Ash.Query.limit(Huddl, @coming_up_limit)
         ) do
      {:ok, huddlz} ->
        Enum.map(huddlz, &day_entry(&1, user))

      {:error, reason} ->
        Logger.warning("CalendarLive Coming up read failed: #{inspect(reason)}")
        []
    end
  end

  defp load_coming_up_entries(_user, _implicit_current_day?, _entries, _today, _time_zone),
    do: []

  defp browser_time_zone(socket) do
    socket
    |> get_connect_params()
    |> TimeZone.from_connect_params()
  end

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

  defp day_entry(huddl, user) do
    roles =
      MapSet.new()
      |> maybe_add_role(huddl.creator_id == user.id, :hosting)
      |> maybe_add_role(huddl.waitlisted_rsvp_for_actor, :waitlisted)
      |> maybe_add_role(huddl.confirmed_rsvp_for_actor, :attending)

    build_day_entry(huddl, roles)
  end

  defp maybe_add_role(roles, true, role), do: MapSet.put(roles, role)
  defp maybe_add_role(roles, false, _role), do: roles

  defp build_day_entry(huddl, roles) do
    entry = %{huddl: huddl, roles: roles}
    Map.put(entry, :card_status, day_card_status(entry))
  end

  defp day_relationship_label(%{card_status: nil}), do: nil
  defp day_relationship_label(%{card_status: status}), do: status.label

  defp day_relationship_variant(%{card_status: nil}), do: :default
  defp day_relationship_variant(%{card_status: status}), do: status.variant

  defp day_card_status(%{huddl: %{status: status}} = entry) do
    case HuddlStatus.contextual_override(status) do
      nil -> day_relationship_status(entry, status)
      presentation -> struct!(EntryStatus, presentation)
    end
  end

  defp day_relationship_status(entry, :completed), do: past_status(entry)
  defp day_relationship_status(entry, _status), do: relationship_status(entry)

  defp primary_relationship(roles) do
    cond do
      MapSet.member?(roles, :hosting) -> :hosting
      MapSet.member?(roles, :waitlisted) -> :waitlisted
      MapSet.member?(roles, :attending) -> :attending
      true -> nil
    end
  end

  defp in_focus_month?(
         %{starts_at: %DateTime{} = starts_at},
         %Date{year: year, month: month},
         time_zone
       ) do
    date = starts_at |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()
    date.year == year && date.month == month
  end

  defp in_focus_month?(_, _, _), do: false

  defp same_month?(%Date{year: year, month: month}, %Date{year: year, month: month}), do: true
  defp same_month?(_left, _right), do: false

  defp shift_month(date, delta) do
    total = date.year * 12 + (date.month - 1) + delta
    Date.new!(Integer.floor_div(total, 12), Integer.mod(total, 12) + 1, 1)
  end

  defp week_path(week_start) do
    ~p"/calendar?#{[view: "week", date: Date.to_iso8601(week_start)]}"
  end

  defp day_path(date) do
    ~p"/calendar?#{[view: "day", date: Date.to_iso8601(date)]}"
  end

  defp month_day_path(month, selected_date) do
    ~p"/calendar?#{[view: "month", month: format_month_param(month), date: Date.to_iso8601(selected_date)]}"
  end

  defp previous_period_path(:week, _focus_month, _week_start, selected_date),
    do: week_path(Date.add(selected_date, -7))

  defp previous_period_path(:day, _focus_month, _week_start, selected_date),
    do: day_path(Date.add(selected_date, -1))

  defp previous_period_path(:month, focus_month, _week_start, today) do
    month = shift_month(focus_month, -1)
    month_day_path(month, default_month_date(month, today))
  end

  defp next_period_path(:week, _focus_month, _week_start, selected_date),
    do: week_path(Date.add(selected_date, 7))

  defp next_period_path(:day, _focus_month, _week_start, selected_date),
    do: day_path(Date.add(selected_date, 1))

  defp next_period_path(:month, focus_month, _week_start, today) do
    month = shift_month(focus_month, 1)
    month_day_path(month, default_month_date(month, today))
  end

  defp current_period_path(:week, today), do: week_path(today)
  defp current_period_path(:day, _today), do: ~p"/calendar"
  defp current_period_path(:month, today), do: month_day_path(first_of_month(today), today)

  defp current_period_label(:week), do: "This week"
  defp current_period_label(:month), do: "This month"
  defp current_period_label(:day), do: "Today"

  defp period_navigation_anchor(:month, _selected_date, today), do: today
  defp period_navigation_anchor(_view_mode, selected_date, _today), do: selected_date

  defp period_navigation_label(:day, direction), do: "#{direction} day"
  defp period_navigation_label(:week, direction), do: "#{direction} week"
  defp period_navigation_label(_view_mode, direction), do: "#{direction} month"

  defp period_title(:week, _focus_month, week_start, week_end, _selected_date),
    do: format_week(week_start, week_end)

  defp period_title(:day, _focus_month, _week_start, _week_end, selected_date),
    do: format_full_date(selected_date)

  defp period_title(_view_mode, focus_month, _week_start, _week_end, _selected_date),
    do: format_month(focus_month)

  defp period_count(:month, _entries, in_month_count), do: in_month_count
  defp period_count(_view_mode, entries, _in_month_count), do: length(entries)

  defp day_tab_path(:day, selected_date, today) when selected_date == today, do: ~p"/calendar"

  defp day_tab_path(_view_mode, selected_date, _today), do: day_path(selected_date)

  defp week_tab_path(selected_date), do: week_path(selected_date)

  defp month_tab_path(:month, focus_month, selected_date, _today),
    do: month_day_path(focus_month, selected_date)

  defp month_tab_path(_view_mode, _focus_month, selected_date, _today),
    do: month_day_path(first_of_month(selected_date), selected_date)

  defp default_month_date(month, today) do
    if same_month?(month, today), do: today, else: month
  end

  defp format_month_param(%Date{year: y, month: m}) do
    "#{y}-#{String.pad_leading(to_string(m), 2, "0")}"
  end

  defp format_month(%Date{year: y, month: m}) do
    {:ok, date} = Date.new(y, m, 1)
    Calendar.strftime(date, "%B %Y")
  end

  defp format_week(%Date{year: year} = week_start, %Date{year: year} = week_end) do
    "#{Calendar.strftime(week_start, "%b %-d")} – #{Calendar.strftime(week_end, "%b %-d, %Y")}"
  end

  defp format_week(week_start, week_end) do
    "#{Calendar.strftime(week_start, "%b %-d, %Y")} – #{Calendar.strftime(week_end, "%b %-d, %Y")}"
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

  defp month_day_accessible_label(day, focus_month, today, summaries) do
    case Map.get(summaries, day) do
      nil ->
        day_accessible_label(day, focus_month, today)

      %MonthDaySummary{accessible_text: accessible_text} ->
        day_accessible_label(day, focus_month, today) <> ", " <> accessible_text
    end
  end

  defp build_month_day_summaries(entries, grid_start, grid_end, time_zone) do
    entries
    |> Enum.reduce(%{}, fn entry, summaries ->
      Enum.reduce(
        month_dates_for(entry.huddl, grid_start, grid_end, time_zone),
        summaries,
        fn day, acc -> Map.update(acc, day, [entry], &[entry | &1]) end
      )
    end)
    |> Map.new(fn {day, day_entries} ->
      {day, summarize_month_day(Enum.reverse(day_entries))}
    end)
  end

  defp month_dates_for(%{starts_at: starts_at, ends_at: ends_at}, grid_start, grid_end, time_zone) do
    first_day = starts_at |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()

    last_day =
      ends_at
      |> DateTime.add(-1, :microsecond)
      |> DateTime.shift_zone!(time_zone)
      |> DateTime.to_date()

    first_day = if Date.before?(first_day, grid_start), do: grid_start, else: first_day
    last_day = if Date.after?(last_day, grid_end), do: grid_end, else: last_day

    if Date.after?(first_day, last_day), do: [], else: Date.range(first_day, last_day)
  end

  defp summarize_month_day(entries) do
    {cancelled, active} = Enum.split_with(entries, &cancelled_month_entry?/1)
    visible_active = Enum.take(active, 3)
    overflow_count = max(length(active) - length(visible_active), 0)

    %MonthDaySummary{
      active: Enum.map(visible_active, &month_indicator/1),
      cancelled_count: length(cancelled),
      overflow_count: overflow_count,
      accessible_text: month_day_summary_text(active, cancelled, overflow_count)
    }
  end

  defp cancelled_month_entry?(%{huddl: %{status: :cancelled}}), do: true
  defp cancelled_month_entry?(_entry), do: false

  defp month_indicator(entry) do
    %{status: month_relationship_status(entry), title: entry.huddl.title}
  end

  defp month_relationship_status(%{roles: roles}) do
    relationship = primary_relationship(roles) || :group_opportunity

    @month_relationship_presentations
    |> Map.fetch!(relationship)
    |> then(&struct!(EntryStatus, &1))
  end

  defp month_day_summary_text(active, cancelled, overflow_count) do
    visible_relationships =
      active
      |> Enum.take(3)
      |> Enum.map(fn entry ->
        status = month_relationship_status(entry)
        "#{status.label}: #{entry.huddl.title}"
      end)

    overflow = if overflow_count > 0, do: ["#{overflow_count} additional huddlz"], else: []

    cancelled_text =
      case length(cancelled) do
        0 -> []
        1 -> ["1 cancelled Personal huddl"]
        count -> ["#{count} cancelled Personal huddlz"]
      end

    (visible_relationships ++ overflow ++ cancelled_text)
    |> Enum.join(", ")
  end

  defp entry_status(
         %{huddl: %{status: status}} = entry,
         %Date{} = today,
         time_zone
       ) do
    case HuddlStatus.contextual_override(status) do
      nil -> timed_entry_status(entry, today, time_zone)
      presentation -> struct!(EntryStatus, presentation)
    end
  end

  defp timed_entry_status(%{huddl: %{starts_at: starts_at}} = entry, today, time_zone) do
    starts_on = starts_at |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()

    case Date.compare(starts_on, today) do
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

  defp month_legend_items(:month) do
    relationship_items =
      Enum.map(@month_relationship_order, fn relationship ->
        @month_relationship_presentations
        |> Map.fetch!(relationship)
        |> then(&struct!(EntryStatus, &1))
      end)

    relationship_items ++
      [
        %EntryStatus{key: "cancelled", label: "Cancelled", variant: :muted, rank: 5},
        %EntryStatus{
          key: "overflow",
          label: "+N additional huddlz",
          variant: :overflow,
          rank: 6
        }
      ]
  end

  defp month_legend_items(_view_mode), do: []

  defp legend_items(entries, today, time_zone) do
    entries
    |> Enum.map(&entry_status(&1, today, time_zone))
    |> Enum.reject(&is_nil/1)
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
          <p>Your relevant huddlz in chronological order.</p>
        </div>
      </div>

      <div
        id="calendar-time-zone"
        phx-hook="CalendarTimeZone"
        data-time-zone={@time_zone}
      >
        <form id="calendar-display-time-zone-form" phx-change="update_display_time_zone">
          <.select
            id="calendar-display-time-zone"
            name="display_time_zone"
            label="Calendar time zone"
            value={TimeZone.preference_selection(@current_user)}
            options={@time_zone_options}
          />
        </form>
      </div>

      <div class="cal-toolbar">
        <div class="cal-nav">
          <.link
            id="calendar-previous-period"
            patch={
              previous_period_path(
                @view_mode,
                @focus_month,
                @week_start,
                period_navigation_anchor(@view_mode, @selected_date, @today)
              )
            }
            class="cal-nav-btn"
            aria-label={period_navigation_label(@view_mode, "Previous")}
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
            <span class="sr-only">{period_navigation_label(@view_mode, "Previous")}</span>
          </.link>
          <.link
            id="calendar-current-period"
            patch={current_period_path(@view_mode, @today)}
            class="cal-nav-today"
          >
            {current_period_label(@view_mode)}
          </.link>
          <.link
            id="calendar-next-period"
            patch={
              next_period_path(
                @view_mode,
                @focus_month,
                @week_start,
                period_navigation_anchor(@view_mode, @selected_date, @today)
              )
            }
            class="cal-nav-btn"
            aria-label={period_navigation_label(@view_mode, "Next")}
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
            <span class="sr-only">{period_navigation_label(@view_mode, "Next")}</span>
          </.link>
        </div>

        <.link
          id="calendar-control"
          patch={month_tab_path(@view_mode, @focus_month, @selected_date, @today)}
          class="cal-period-title"
          aria-label="Open Month for selected date"
        >
          <span class="sr-only">Open Month for selected date</span>
          <span id={"calendar-#{@view_mode}-heading"} class="cal-period-name">
            {period_title(
              @view_mode,
              @focus_month,
              @week_start,
              @week_end,
              @selected_date
            )}
          </span>
          <span id={"calendar-#{@view_mode}-count"} class="cal-period-count">
            ({format_count(period_count(@view_mode, @entries, @in_month_count))})
          </span>
        </.link>

        <div id="calendar-range-tabs" class="cal-view-tabs">
          <.link
            id="calendar-view-day"
            patch={day_tab_path(@view_mode, @selected_date, @today)}
            class={["scope-tab", @view_mode == :day && "is-active"]}
            aria-current={if @view_mode == :day, do: "page"}
          >
            Day
          </.link>
          <.link
            id="calendar-view-week"
            patch={week_tab_path(@selected_date)}
            class={["scope-tab", @view_mode == :week && "is-active"]}
            aria-current={if @view_mode == :week, do: "page"}
          >
            Week
          </.link>
          <.link
            id="calendar-view-month"
            patch={month_tab_path(@view_mode, @focus_month, @selected_date, @today)}
            class={["scope-tab", @view_mode == :month && "is-active"]}
            aria-current={if @view_mode == :month, do: "page"}
          >
            Month
          </.link>
        </div>
      </div>

      <%= case @view_mode do %>
        <% :day -> %>
          <.day_view
            entries_empty?={@entries_empty?}
            coming_up_empty?={@coming_up_empty?}
            entries={@streams.entries}
            coming_up_entries={@streams.coming_up_entries}
            time_zone={@time_zone}
            selected_date={@selected_date}
            current_day?={@current_day?}
          />
        <% :week -> %>
          <.week_view
            week_start={@week_start}
            week_end={@week_end}
            entries_empty?={@entries_empty?}
            entries={@streams.entries}
            time_zone={@time_zone}
          />
        <% :month -> %>
          <.month_grid
            day_summaries={@month_day_summaries}
            entries={@streams.entries}
            focus_month={@focus_month}
            grid_start={@grid_start}
            entries_empty?={@entries_empty?}
            selected_date={@selected_date}
            today={@today}
            time_zone={@time_zone}
          />
      <% end %>

      <div
        :if={!@month_legend_empty?}
        id="calendar-month-legend"
        class="cal-legend"
        aria-label="Month indicator legend"
        phx-update="stream"
      >
        <span
          :for={{id, item} <- @streams.month_legend_items}
          id={id}
          class="cal-legend-item"
          data-status={item.key}
          data-variant={item.variant}
        >
          <span class={legend_swatch_class(item)} aria-hidden="true"></span>
          {item.label}
        </span>
      </div>

      <div
        :if={!@legend_empty?}
        id="calendar-legend"
        class="cal-legend"
        aria-label={if @view_mode == :month, do: "Selected Day statuses", else: "Calendar statuses"}
        phx-update="stream"
      >
        <span
          :for={{id, item} <- @streams.legend_items}
          id={id}
          class="cal-legend-item"
          data-status={item.key}
          data-variant={item.variant}
        >
          <span class={legend_swatch_class(item)} aria-hidden="true"></span>
          {item.label}
        </span>
      </div>
    </Layouts.app>
    """
  end

  attr :week_start, Date, required: true
  attr :week_end, Date, required: true
  attr :entries_empty?, :boolean, required: true
  attr :entries, :any, required: true
  attr :time_zone, :string, required: true

  defp week_view(assigns) do
    ~H"""
    <section
      id="calendar-week"
      aria-labelledby="calendar-week-title"
      aria-describedby="calendar-week-range"
    >
      <h2 id="calendar-week-title" class="sr-only">Week</h2>
      <p id="calendar-week-range" class="sr-only">
        Week from {format_full_date(@week_start)} through {format_full_date(@week_end)}
      </p>
      <div id="calendar-week-list" class="grid" phx-update="stream">
        <p :if={@entries_empty?} id="calendar-week-empty" class="empty-state muted">
          Nothing on your calendar this week.
        </p>
        <.calendar_huddl_card
          :for={{id, entry} <- @entries}
          id={id}
          entry={entry}
          time_zone={@time_zone}
        />
      </div>
    </section>
    """
  end

  attr :entries_empty?, :boolean, required: true
  attr :coming_up_empty?, :boolean, required: true
  attr :entries, :any, required: true
  attr :coming_up_entries, :any, required: true
  attr :time_zone, :string, required: true
  attr :selected_date, Date, required: true
  attr :current_day?, :boolean, required: true

  defp day_view(assigns) do
    ~H"""
    <section id="calendar-day" aria-labelledby="calendar-day-title">
      <h2 id="calendar-day-title" class="sr-only">{format_full_date(@selected_date)}</h2>
      <div id="calendar-day-list" class="grid" phx-update="stream">
        <p :if={@entries_empty?} id="calendar-day-empty" class="empty-state muted">
          {empty_day_message(@current_day?)}
          <.link id="calendar-discover-link" navigate={~p"/discover"}>Discover huddlz</.link>
        </p>
        <.calendar_huddl_card
          :for={{id, entry} <- @entries}
          id={id}
          entry={entry}
          time_zone={@time_zone}
        />
      </div>

      <section
        :if={@entries_empty? && !@coming_up_empty?}
        id="calendar-coming-up"
        aria-labelledby="calendar-coming-up-title"
      >
        <h2 id="calendar-coming-up-title">Coming up</h2>
        <div id="calendar-coming-up-list" class="grid" phx-update="stream">
          <.calendar_huddl_card
            :for={{id, entry} <- @coming_up_entries}
            id={id}
            entry={entry}
            time_zone={@time_zone}
          />
        </div>
      </section>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :entry, :map, required: true
  attr :time_zone, :string, required: true

  defp calendar_huddl_card(assigns) do
    ~H"""
    <.shared_huddl_card
      id={@id}
      huddl={@entry.huddl}
      relationship_label={day_relationship_label(@entry)}
      relationship_variant={day_relationship_variant(@entry)}
      relationship_testid="calendar-relationship"
      display_time_zone={@time_zone}
    />
    """
  end

  attr :focus_month, Date, required: true
  attr :grid_start, Date, required: true
  attr :entries, :any, required: true
  attr :day_summaries, :map, required: true
  attr :entries_empty?, :boolean, required: true
  attr :selected_date, Date, required: true
  attr :today, Date, required: true
  attr :time_zone, :string, required: true

  defp month_grid(assigns) do
    ~H"""
    <div id="calendar-month">
      <div
        id="calendar-month-grid"
        class="cal-month-grid"
        role="grid"
        aria-label={"Month calendar for #{format_month(@focus_month)}"}
      >
        <div role="row" class="cal-month-row">
          <span
            :for={{short, full} <- weekday_names()}
            role="columnheader"
            class="cal-month-weekday"
            aria-label={full}
          >
            {short}
          </span>
        </div>
        <div :for={week <- weeks_in_grid(@grid_start)} role="row" class="cal-month-row">
          <.link
            :for={day <- week}
            id={"calendar-month-day-#{Date.to_iso8601(day)}"}
            patch={month_day_selection_path(first_of_month(day), day)}
            phx-click={JS.focus(to: "#calendar-month-selection")}
            role="gridcell"
            class={month_day_class(day, @focus_month, @selected_date, @today)}
            aria-label={month_day_accessible_label(day, @focus_month, @today, @day_summaries)}
            aria-current={if Date.compare(day, @selected_date) == :eq, do: "date"}
          >
            <time datetime={Date.to_iso8601(day)}>{day.day}</time>
            <span :if={Date.compare(day, @today) == :eq} class="sr-only">Today</span>
            <.month_day_indicators summary={Map.get(@day_summaries, day)} />
          </.link>
        </div>
      </div>

      <section
        id="calendar-month-selection"
        class="cal-month-selection"
        aria-labelledby="calendar-month-selection-title"
        tabindex="-1"
      >
        <h2 id="calendar-month-selection-title">{format_full_date(@selected_date)}</h2>
        <div id="calendar-month-day-huddlz" class="grid" phx-update="stream">
          <p :if={@entries_empty?} id="calendar-month-day-empty" class="empty-state muted">
            Nothing on your calendar this day.
          </p>
          <.calendar_huddl_card
            :for={{id, entry} <- @entries}
            id={id}
            entry={entry}
            time_zone={@time_zone}
          />
        </div>
      </section>
    </div>
    """
  end

  defp month_day_selection_path(month, selected_date) do
    month_day_path(month, selected_date) <> "#calendar-month-selection"
  end

  attr :summary, :any, default: nil

  defp month_day_indicators(%{summary: nil} = assigns), do: ~H""

  defp month_day_indicators(assigns) do
    ~H"""
    <span class="cal-month-indicators" aria-hidden="true">
      <span
        :for={indicator <- @summary.active}
        class={["cal-month-indicator", indicator.status.variant]}
        data-month-indicator="active"
        data-status={indicator.status.key}
        data-variant={indicator.status.variant}
        title={"#{indicator.status.label}: #{indicator.title}"}
      ></span>
      <span
        :if={@summary.overflow_count > 0}
        class="cal-month-overflow"
        data-month-overflow
      >
        +{@summary.overflow_count}
      </span>
      <span
        :if={@summary.cancelled_count > 0}
        class="cal-month-indicator muted is-cancelled"
        data-month-indicator="cancelled"
        data-variant="muted"
        title={"#{@summary.cancelled_count} cancelled Personal huddlz"}
      ></span>
    </span>
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

  defp month_day_class(day, focus_month, selected_date, today) do
    [
      "cal-month-day",
      !day_in_focus?(day, focus_month) && "is-outside-month",
      Date.compare(day, today) == :eq && "is-today",
      Date.compare(day, selected_date) == :eq && "is-selected"
    ]
  end

  defp empty_day_message(true), do: "Nothing on your calendar today."
  defp empty_day_message(false), do: "Nothing on your calendar this day."
end
