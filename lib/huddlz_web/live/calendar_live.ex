defmodule HuddlzWeb.CalendarLive do
  @moduledoc """
  LiveView at `/calendar`. Personal calendar of huddlz the signed-in user
  is hosting, attending, or watching from the waitlist. Month grid by
  default with an agenda toggle; `?month=YYYY-MM` and `?view=month|agenda`
  drive state.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts
  require Logger

  @card_loads [:status, :group]

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My calendar")
     |> assign(:today, Date.utc_today())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    focus_month = parse_month(params["month"], socket.assigns.today)
    view_mode = parse_view(params["view"])
    {grid_start, grid_end} = month_grid_window(focus_month)
    user = socket.assigns.current_user

    entries = load_entries(user, grid_start, grid_end)
    entries_by_day = group_by_day(entries)
    in_month_count = Enum.count(entries, &in_focus_month?(&1.huddl, focus_month))

    {:noreply,
     socket
     |> assign(:focus_month, focus_month)
     |> assign(:view_mode, view_mode)
     |> assign(:grid_start, grid_start)
     |> assign(:grid_end, grid_end)
     |> assign(:entries, entries)
     |> assign(:entries_by_day, entries_by_day)
     |> assign(:in_month_count, in_month_count)}
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

  defp load_entries(user, grid_start, grid_end) do
    grid_start_dt = DateTime.new!(grid_start, ~T[00:00:00], "Etc/UTC")
    grid_end_dt = DateTime.new!(grid_end, ~T[23:59:59], "Etc/UTC")

    [:hosting, :attending, :waitlisted]
    |> Enum.flat_map(fn role -> fetch(user, role) end)
    |> Enum.uniq_by(& &1.huddl.id)
    |> Enum.filter(fn %{huddl: h} ->
      h.starts_at &&
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
    view_str = if view == :agenda, do: "agenda"

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

  defp day_in_focus?(%Date{} = day, %Date{year: y, month: m}),
    do: day.year == y and day.month == m

  defp pill_class_for(entry, day, focus_month, today) do
    base = base_pill_class(entry, today)
    if day_in_focus?(day, focus_month), do: base, else: base <> " out-of-month-pill"
  end

  defp base_pill_class(%{role: role, huddl: %{starts_at: starts_at}}, %Date{} = today) do
    starts_date = DateTime.to_date(starts_at)
    past? = Date.compare(starts_date, today) == :lt

    cond do
      past? -> "cal-pill past"
      role == :waitlisted -> "cal-pill tentative"
      true -> "cal-pill"
    end
  end

  defp format_pill_label(%{huddl: %{starts_at: dt, title: title}}) do
    time = Calendar.strftime(dt, "%-I:%M %p")
    "#{time} · #{title}"
  end

  defp huddl_path(%{huddl: %{id: id, group: %{slug: slug}}}),
    do: ~p"/groups/#{slug}/huddlz/#{id}"

  defp agenda_entries(entries, focus_month) do
    entries
    |> Enum.filter(fn %{huddl: h} -> in_focus_month?(h, focus_month) end)
    |> Enum.sort_by(fn %{huddl: %{starts_at: dt}} -> dt end, DateTime)
  end

  defp agenda_pill_variant(%{role: role, huddl: %{starts_at: dt}}, %Date{} = today) do
    past? = Date.compare(DateTime.to_date(dt), today) == :lt

    cond do
      past? -> :muted
      role == :waitlisted -> :warn
      true -> :default
    end
  end

  defp agenda_pill_label(%{role: role, huddl: %{starts_at: dt}}, %Date{} = today) do
    past? = Date.compare(DateTime.to_date(dt), today) == :lt

    cond do
      past? -> "Past"
      role == :hosting -> "Hosting"
      role == :waitlisted -> "Waitlist"
      true -> "Going"
    end
  end

  defp format_agenda_when(%DateTime{} = dt) do
    Calendar.strftime(dt, "%a %b %-d · %-I:%M %p")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.v3_app flash={@flash} current_user={@current_user} active="calendar">
      <div class="page-head">
        <div>
          <h1>My calendar</h1>
          <p>
            Huddlz you're hosting, attending, or watching from the waitlist — laid out across the month.
          </p>
        </div>
      </div>

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
            patch={month_path(@focus_month, :month)}
            class={["scope-tab", @view_mode == :month && "is-active"]}
          >
            Month
          </.link>
          <.link
            patch={month_path(@focus_month, :agenda)}
            class={["scope-tab", @view_mode == :agenda && "is-active"]}
          >
            Agenda
          </.link>
        </div>
      </div>

      <%= if @view_mode == :month do %>
        <.month_grid
          focus_month={@focus_month}
          grid_start={@grid_start}
          entries_by_day={@entries_by_day}
          today={@today}
        />
      <% else %>
        <.agenda_view entries={@entries} focus_month={@focus_month} today={@today} />
      <% end %>

      <div class="cal-legend">
        <span class="cal-legend-item">
          <span class="cal-legend-swatch" style="background:var(--cyan)"></span> Going
        </span>
        <span class="cal-legend-item">
          <span class="cal-legend-swatch" style="background:var(--warn)"></span> Tentative / waitlist
        </span>
        <span class="cal-legend-item">
          <span class="cal-legend-swatch" style="background:var(--muted)"></span> Past
        </span>
      </div>
    </Layouts.v3_app>
    """
  end

  attr :focus_month, Date, required: true
  attr :grid_start, Date, required: true
  attr :entries_by_day, :map, required: true
  attr :today, Date, required: true

  defp month_grid(assigns) do
    ~H"""
    <div class="panel" style="padding:0">
      <div class="cal-grid">
        <div class="cal-day-name">Sun</div>
        <div class="cal-day-name">Mon</div>
        <div class="cal-day-name">Tue</div>
        <div class="cal-day-name">Wed</div>
        <div class="cal-day-name">Thu</div>
        <div class="cal-day-name">Fri</div>
        <div class="cal-day-name">Sat</div>
      </div>
      <div class="cal-grid">
        <%= for day <- days_in_grid(@grid_start) do %>
          <div class={cell_class(day, @focus_month)}>
            <span class={day_num_class(day, @today)}>{day.day}</span>
            <%= for entry <- Map.get(@entries_by_day, day, []) do %>
              <.link
                navigate={huddl_path(entry)}
                class={pill_class_for(entry, day, @focus_month, @today)}
                title={entry.huddl.title}
              >
                {format_pill_label(entry)}
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
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
      <div class="panel">
        <div class="row-list">
          <.link
            :for={entry <- @sorted}
            navigate={huddl_path(entry)}
            class="row"
            style="grid-template-columns: 200px 1fr auto; text-decoration: none"
          >
            <span class="meta">{format_agenda_when(entry.huddl.starts_at)}</span>
            <span class="row-title">{entry.huddl.title}</span>
            <.v3_pill variant={agenda_pill_variant(entry, @today)}>
              {agenda_pill_label(entry, @today)}
            </.v3_pill>
          </.link>
        </div>
      </div>
    <% end %>
    """
  end
end
