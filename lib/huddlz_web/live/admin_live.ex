defmodule HuddlzWeb.AdminLive do
  @moduledoc """
  The admin overview at `/admin`: how huddlz as a whole is doing, over a
  period kept in the URL as `?period=`.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.Sparkline

  alias Huddlz.Admin
  alias Huddlz.Communities.Periods
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
    </Layouts.app>
    """
  end

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
