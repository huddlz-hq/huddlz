defmodule HuddlzWeb.AdminLive do
  @moduledoc """
  The admin overview at `/admin`: how huddlz as a whole is doing, over a
  period kept in the URL as `?period=`.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.HeldChart
  import HuddlzWeb.Components.Sparkline

  alias Huddlz.Admin
  alias Huddlz.Communities.Periods
  alias HuddlzWeb.Components.Card
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :admin_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    period = Periods.parse_period(params["period"])
    stats = Admin.platform_overview!(period, actor: socket.assigns.current_user)
    {:noreply, assign(socket, period: period, stats: stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="admin"
      active_admin_section={:overview}
    >
      <div class="page-head">
        <div>
          <h1>Overview</h1>
          <p>How huddlz as a whole is doing: who is joining, what is being held, and who shows up.</p>
        </div>
        <div class="actions">
          <nav id="overview-period" class="cal-view-tabs" aria-label="Period">
            <.link
              :for={{key, label} <- Periods.periods()}
              patch={~p"/admin?period=#{key}"}
              class={["scope-tab", key == @period && "is-active"]}
              aria-current={if key == @period, do: "page"}
            >
              {label}
            </.link>
          </nav>
        </div>
      </div>

      <p id="overview-summary-scope" class="mb-3 text-sm text-[var(--muted)]">
        Active people, huddlz held, RSVPs and show rate cover the selected period and compare
        with the {Periods.period_label(@period)} before it. People and groups are current totals.
        Days end at midnight UTC.
      </p>
      <div class="kpis six" aria-describedby="overview-summary-scope">
        <div id="kpi-people" class="kpi">
          <div class="label">People</div>
          <div class="value">{@stats.people.count}</div>
          <div class={["delta", @stats.people.joined == 0 && "muted"]}>
            {people_delta(@stats.people, @period)}
          </div>
          <.sparkline id="spark-people" points={@stats.people.spark} />
        </div>
        <div id="kpi-active" class="kpi">
          <div class="label">Active people</div>
          <div class="value">{@stats.active.count}</div>
          <div class={["delta", period_delta_class(@stats.active)]}>
            {period_delta(@stats.active, @period)}
          </div>
          <.sparkline id="spark-active" points={@stats.active.spark} />
        </div>
        <div id="kpi-groups" class="kpi">
          <div class="label">Groups</div>
          <div class="value">{@stats.groups.count}</div>
          <div class={["delta", groups_delta_class(@stats.groups)]}>
            {groups_delta(@stats.groups)}
          </div>
          <.sparkline id="spark-groups" points={@stats.groups.spark} />
        </div>
        <div id="kpi-huddlz" class="kpi">
          <div class="label">Huddlz held</div>
          <div class="value">{@stats.held.count}</div>
          <div class={["delta", period_delta_class(@stats.held)]}>
            {period_delta(@stats.held, @period)}
          </div>
          <.sparkline id="spark-huddlz" points={@stats.held.spark} />
        </div>
        <div id="kpi-rsvps" class="kpi">
          <div class="label">RSVPs</div>
          <div class="value">{@stats.rsvps.count}</div>
          <div class={["delta", period_delta_class(@stats.rsvps)]}>
            {period_delta(@stats.rsvps, @period)}
          </div>
          <.sparkline id="spark-rsvps" points={@stats.rsvps.spark} />
        </div>
        <div id="kpi-showrate" class="kpi">
          <div class="label">Show rate</div>
          <div class={["value", @stats.turnout.counted == 0 && "muted"]}>
            {show_rate_value(@stats.turnout)}
          </div>
          <div class={["delta", @stats.turnout.counted == 0 && "muted"]}>
            {show_rate_delta(@stats.turnout)}
          </div>
          <.sparkline id="spark-showrate" points={@stats.turnout.spark} />
        </div>
      </div>

      <div class="overview-row">
        <div id="held-panel" class="panel">
          <div class="panel-head">
            <div>
              <h2>Huddlz held</h2>
              <div class="panel-sub">{held_sub(@stats.held.unit)}</div>
            </div>
            <div class="stat">
              <span class="big">{@stats.held.count}</span>
              <span class="cmp">{period_delta(@stats.held, @period)}</span>
            </div>
          </div>
          <p :if={quiet?(@stats.held)} class="muted">
            No huddl ended in this period. Once one does, it will show here.
          </p>
          <div :if={!quiet?(@stats.held)} class="held-chart-wrap">
            <.held_chart
              id="held-chart"
              class="wide-only"
              unit={@stats.held.unit}
              buckets={@stats.held.buckets}
            />
            <.held_chart
              id="held-chart-compact"
              class="compact-only"
              width={360}
              compact
              unit={@stats.held.unit}
              buckets={Enum.take(@stats.held.buckets, -5)}
            />
            <div class="legend">
              <span><i class="sq room"></i>Held</span>
              <span :if={@stats.held.cancelled > 0}><i class="sq none"></i>Cancelled</span>
            </div>
          </div>
        </div>

        <div id="coverage-panel" class="panel">
          <div class="panel-head">
            <div>
              <h2>Turnout coverage</h2>
              <div class="panel-sub">{coverage_sub(@stats.turnout)}</div>
            </div>
          </div>
          <p :if={@stats.turnout.past == 0} class="muted">
            No huddl ended in this period, so there was nothing to count.
          </p>
          <div :if={@stats.turnout.past > 0} class="coverage">
            <div class="coverage-bar" role="img" aria-label={coverage_label(@stats.turnout)}>
              <span
                class="counted"
                style={"width: #{share(@stats.turnout.counted, @stats.turnout.past)}%"}
              ></span>
              <span
                class="skipped"
                style={"width: #{share(@stats.turnout.skipped, @stats.turnout.past)}%"}
              ></span>
              <span
                class="unanswered"
                style={"width: #{share(@stats.turnout.unanswered, @stats.turnout.past)}%"}
              ></span>
            </div>
            <div class="coverage-rows">
              <.coverage_row
                kind="counted"
                label="Counted"
                count={@stats.turnout.counted}
                of={@stats.turnout.past}
              />
              <.coverage_row
                kind="skipped"
                label="Skipped by the organizer"
                count={@stats.turnout.skipped}
                of={@stats.turnout.past}
              />
              <.coverage_row
                kind="unanswered"
                label="Not answered"
                count={@stats.turnout.unanswered}
                of={@stats.turnout.past}
              />
            </div>
            <p class="coverage-note">The show rate is measured over the counted huddlz only.</p>
          </div>
        </div>
      </div>

      <div class="overview-row">
        <div id="active-groups-panel" class="panel">
          <div class="panel-head">
            <div>
              <h2>Most active groups</h2>
              <div class="panel-sub">
                By RSVPs gathered in the period. Show rate is over the group's counted huddlz.
              </div>
            </div>
            <span :if={@stats.active_groups.groups != []} class="panel-sub">
              {length(@stats.active_groups.groups)} of {@stats.active_groups.ranked}
            </span>
          </div>
          <p :if={@stats.active_groups.groups == []} class="muted">
            No group held a huddl in this period.
          </p>
          <table :if={@stats.active_groups.groups != []} id="active-groups" class="group-table">
            <thead>
              <tr>
                <th>Group</th>
                <th class="n">Huddlz</th>
                <th class="n">RSVPs</th>
                <th class="n">Show rate</th>
                <th class="n">Members</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={{group, idx} <- Enum.with_index(@stats.active_groups.groups)}
                id={"active-group-#{group.id}"}
              >
                <td data-label="Group">
                  <.link navigate={~p"/groups/#{group.slug}"} class="group-name">
                    <span class={["group-mark", group_mark_variant(idx)]}>
                      {Card.group_initials(group.name)}
                    </span>
                    {group.name}
                  </.link>
                </td>
                <td class="n" data-label="Huddlz">{group.held}</td>
                <td class="n" data-label="RSVPs">{group.rsvps}</td>
                <td class={["n", is_nil(group.show_rate) && "muted"]} data-label="Show rate">
                  {show_rate_value(group)}
                </td>
                <td class="n" data-label="Members">{group.members}</td>
              </tr>
            </tbody>
          </table>
          <p :if={@stats.active_groups.quiet > 0} class="note-line">
            <.icon name="hero-calendar" class="size-4" />
            <span>{quiet_groups_line(@stats.active_groups, @period)}</span>
          </p>
        </div>

        <div id="coming-up" class="panel">
          <div class="panel-head">
            <div>
              <h2>Coming up</h2>
              <div class="panel-sub">The next {@stats.coming_up.days} days across the platform</div>
            </div>
            <.link navigate={~p"/discover"} class="pill">Discover</.link>
          </div>
          <p :if={@stats.coming_up.count == 0} class="muted">
            Nothing scheduled in the next {@stats.coming_up.days} days.
          </p>
          <div :if={@stats.coming_up.count > 0}>
            <div class="stat-row">
              <div id="coming-up-huddlz" class="stat">
                <span class="big">{@stats.coming_up.count}</span>
                <span class="cmp">{if @stats.coming_up.count == 1, do: "huddl", else: "huddlz"} scheduled</span>
              </div>
              <div id="coming-up-rsvps" class="stat">
                <span class="big">{@stats.coming_up.rsvps}</span>
                <span class="cmp">RSVPs so far</span>
              </div>
              <div id="coming-up-groups" class="stat">
                <span class="big">{@stats.coming_up.groups}</span>
                <span class="cmp">{if @stats.coming_up.groups == 1, do: "group", else: "groups"}</span>
              </div>
            </div>
            <div class="upcoming">
              <div :for={huddl <- @stats.coming_up.next} class="upcoming-row">
                <span class="upcoming-date">{short_date(huddl)}</span>
                <span class="upcoming-copy">
                  <.link navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}>
                    {huddl.title}
                  </.link>
                  <small>{huddl.group.name}</small>
                </span>
                <span class="upcoming-count">{signups_figure(huddl)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :kind, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :of, :integer, required: true

  defp coverage_row(assigns) do
    ~H"""
    <div class="coverage-row">
      <i class={["sq", @kind]}></i>
      <span>{@label}</span>
      <b>{@count}</b>
      <small>{share(@count, @of)}%</small>
    </div>
    """
  end

  defp share(_count, 0), do: 0
  defp share(count, of), do: round(count * 100 / of)

  defp coverage_label(%{counted: counted, skipped: skipped, unanswered: unanswered}),
    do: "#{counted} counted, #{skipped} skipped, #{unanswered} not answered"

  defp coverage_sub(%{past: 0}), do: "What organizers did with the turnout prompt after a huddl"

  defp coverage_sub(%{past: past}),
    do:
      "What organizers did with the turnout prompt after the #{past} #{if past == 1, do: "huddl", else: "huddlz"} that ended."

  defp quiet?(%{count: 0, cancelled: 0}), do: true
  defp quiet?(_held), do: false

  defp held_sub(:month), do: "Published huddlz that ended in each month. Dashed means cancelled."

  defp held_sub(:fortnight),
    do: "Published huddlz that ended in each fortnight. Dashed means cancelled."

  defp held_sub(:week), do: "Published huddlz that ended in each week. Dashed means cancelled."

  defp quiet_groups_line(%{quiet: quiet, never_held: never}, period) do
    label = Periods.period_label(period)
    groups = if quiet == 1, do: "group", else: "groups"
    held = "#{quiet} #{groups} held nothing in these #{label}"

    case never do
      0 -> held <> "."
      1 -> held <> "; 1 of them has never held a huddl."
      n -> held <> "; #{n} of them have never held a huddl."
    end
  end

  defp group_mark_variant(idx) do
    case rem(idx, 3) do
      0 -> ""
      1 -> "mark-magenta"
      2 -> "mark-warm"
    end
  end

  defp short_date(%{starts_at: starts_at, time_zone: time_zone}) do
    starts_at |> DateTime.shift_zone!(time_zone) |> Calendar.strftime("%b %-d")
  end

  defp signups_figure(%{capacity: nil, rsvp_count: count}), do: "#{count}"
  defp signups_figure(%{capacity: capacity, rsvp_count: count}), do: "#{count} / #{capacity}"

  # KPI deltas read as a sentence; a zero is quiet, never a warning.
  defp people_delta(%{joined: 0}, period), do: "No one new in #{Periods.period_label(period)}"
  defp people_delta(%{joined: n}, period), do: "+#{n} in #{Periods.period_label(period)}"

  defp period_delta(%{count: 0}, _period), do: "Nothing in this period"

  defp period_delta(%{previous: 0}, period),
    do: "None in the previous #{Periods.period_label(period)}"

  defp period_delta(%{count: count, previous: previous}, period) do
    change = round((count - previous) * 100 / previous)
    sign = if change < 0, do: "−", else: "+"
    "#{sign}#{abs(change)}% vs previous #{Periods.period_label(period)}"
  end

  defp period_delta_class(%{count: 0}), do: "muted"
  defp period_delta_class(%{previous: 0}), do: "muted"
  defp period_delta_class(%{count: count, previous: previous}) when count < previous, do: "muted"
  defp period_delta_class(_figure), do: nil

  defp groups_delta(%{started: 0, held: 0}), do: "Nothing in this period"

  defp groups_delta(%{started: started, held: held}),
    do: "+#{started} started · #{held} held a huddl"

  defp groups_delta_class(%{started: 0, held: 0}), do: "muted"
  defp groups_delta_class(_groups), do: nil

  defp show_rate_value(%{show_rate: nil}), do: "—"
  defp show_rate_value(%{show_rate: rate}), do: "#{rate}%"

  defp show_rate_delta(%{counted: 0}), do: "No turnout recorded yet"

  defp show_rate_delta(%{counted: counted, past: past}),
    do: "#{counted} of #{past} past #{if past == 1, do: "huddl", else: "huddlz"} counted"
end
