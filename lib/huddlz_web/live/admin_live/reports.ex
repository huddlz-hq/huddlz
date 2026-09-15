defmodule HuddlzWeb.AdminLive.Reports do
  @moduledoc """
  The administrators' report queue at `/admin/reports`: what members asked
  an administrator to look at, open or handled, newest first. A row opens
  into a review card with the reporter's words, the account as far as the
  administrator can ordinarily see it, the other open reports on it, the
  same suspend dialog Users has, and Mark handled. A report never
  suspends anyone on its own.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.AdminLive.AccountActionDialog

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :admin_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> assign(:action, nil)
     |> assign(:review, nil)
     |> stream_configure(:reports, dom_id: &"report-#{&1.id}")
     |> stream(:reports, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = if params["scope"] == "handled", do: :handled, else: :open

    socket =
      socket
      |> assign(:scope, scope)
      |> assign(:account_id, valid_id(params["account_id"]))
      |> assign(:review, nil)
      |> load_reports()

    review =
      case valid_id(params["review"]) do
        nil -> nil
        id -> build_review(id, socket)
      end

    {:noreply, set_review(socket, review)}
  end

  @impl true
  def handle_event("review", %{"id" => id}, socket) do
    review =
      if socket.assigns.review && socket.assigns.review.report.id == id,
        do: nil,
        else: build_review(id, socket)

    {:noreply, set_review(socket, review)}
  end

  def handle_event("collapse_review", _params, socket) do
    {:noreply, set_review(socket, nil)}
  end

  def handle_event("mark_handled", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    with {:ok, report} <- Accounts.get_account_report(id, actor: actor),
         {:ok, _handled} <- Accounts.mark_report_handled(report, actor: actor) do
      {:noreply,
       socket
       |> assign(:review, nil)
       |> put_flash(:info, "Report handled")
       |> load_reports()}
    else
      _ ->
        {:noreply,
         socket |> put_flash(:error, "That report is already handled.") |> load_reports()}
    end
  end

  def handle_event("reopen", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    with {:ok, report} <- Accounts.get_account_report(id, actor: actor),
         {:ok, _reopened} <- Accounts.reopen_report(report, actor: actor) do
      {:noreply,
       socket
       |> assign(:review, nil)
       |> put_flash(:info, "Report reopened")
       |> push_patch(
         to: ~p"/admin/reports?review=#{id}&account_id=#{socket.assigns.account_id || ""}"
       )}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Could not reopen this report. It may already be open, expired, or have a newer open report from the same member."
         )
         |> load_reports()}
    end
  end

  def handle_event("open_action", %{"id" => id}, socket) do
    case Accounts.get_user(id, actor: socket.assigns.current_user) do
      {:ok, user} ->
        {:noreply,
         assign(socket, :action, account_action(:suspend, user, socket.assigns.current_user))}

      _ ->
        {:noreply, put_flash(socket, :error, "User not found")}
    end
  end

  def handle_event("cancel_action", _params, socket) do
    {:noreply, assign(socket, :action, nil)}
  end

  def handle_event("validate_action", %{"form" => params}, socket) do
    case socket.assigns.action do
      %{form: form} = action ->
        {:noreply,
         assign(socket, :action, %{action | form: AshPhoenix.Form.validate(form, params)})}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("confirm_action", params, socket) do
    case socket.assigns.action do
      nil ->
        {:noreply, socket}

      %{user: user, form: form} = action ->
        case AshPhoenix.Form.submit(form, params: params["form"] || %{}) do
          {:ok, suspended} ->
            {:noreply,
             socket
             |> assign(:action, nil)
             |> put_flash(:info, "#{suspended.display_name} is suspended")
             |> load_reports()
             |> refresh_review()}

          {:error, form} ->
            {:noreply, assign(socket, :action, %{action | user: user, form: form})}
        end
    end
  end

  # ── data ────────────────────────────────────────────────────────────

  @loads [
    :source,
    :handled,
    reporter: [:current_profile_picture_url],
    handled_by: [],
    reported_user: [:current_profile_picture_url, :open_report_count, :suspended_by]
  ]

  defp load_reports(%{assigns: %{scope: scope}} = socket) do
    actor = socket.assigns.current_user

    reports =
      Accounts.list_account_reports!(
        scope == :handled,
        %{reported_user_id: socket.assigns.account_id},
        actor: actor,
        load: @loads
      )

    filter = %{reported_user_id: socket.assigns.account_id}
    open_count = Accounts.count_account_reports!(false, filter, actor: actor)

    socket
    |> assign(:reports_empty, reports == [])
    |> assign(:report_summary, summary(reports))
    |> stream(:reports, reports, reset: true)
    |> assign(:open_count, open_count)
    |> assign(:handled_count, Accounts.count_account_reports!(true, filter, actor: actor))
    |> assign(:open_report_count, Accounts.count_account_reports!(false, actor: actor))
  end

  defp build_review(report_id, socket) do
    actor = socket.assigns.current_user

    case Accounts.list_account_reports!(
           socket.assigns.scope == :handled,
           %{reported_user_id: socket.assigns.account_id},
           actor: actor,
           load: @loads,
           query: [filter: [id: report_id]]
         ) do
      [] ->
        nil

      [report] ->
        others =
          Accounts.list_account_reports!(false, %{reported_user_id: report.reported_user_id},
            actor: actor,
            load: [:source, reporter: []],
            query: [filter: [id: [not_eq: report.id]]]
          )

        %{report: report, others: others}
    end
  end

  defp set_review(socket, review) do
    previous = socket.assigns.review
    socket = assign(socket, :review, review)
    socket = refresh_review_row(socket, previous)
    refresh_review_row(socket, review)
  end

  defp refresh_review_row(socket, nil), do: socket
  defp refresh_review_row(socket, %{report: report}), do: stream_insert(socket, :reports, report)

  defp refresh_review(%{assigns: %{review: nil}} = socket), do: socket

  defp refresh_review(%{assigns: %{review: %{report: %{id: id}}}} = socket) do
    review = build_review(id, socket)
    socket |> assign(:review, review) |> refresh_review_row(review)
  end

  defp reports_path(scope, nil), do: ~p"/admin/reports?scope=#{scope}"
  defp reports_path(scope, id), do: ~p"/admin/reports?scope=#{scope}&account_id=#{id}"

  defp valid_id(value) do
    case Ecto.UUID.cast(value) do
      {:ok, id} -> id
      :error -> nil
    end
  end

  # ── render ──────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="admin"
      active_admin_section={:reports}
      open_report_count={@open_report_count}
    >
      <div class="page-head">
        <div>
          <h1>Reports</h1>
          <p>
            What members asked an administrator to look at. A report never suspends anyone on its own; you decide from the account.
          </p>
        </div>
      </div>

      <div class="admin-users-bar">
        <div class="chip-group">
          <.chip patch={reports_path(:open, @account_id)} active={@scope == :open} count={@open_count}>
            Open
          </.chip>
          <.chip
            patch={reports_path(:handled, @account_id)}
            active={@scope == :handled}
            count={@handled_count}
          >
            Handled
          </.chip>
        </div>
      </div>

      <p :if={@account_id} class="mb-4 text-sm">
        Showing reports for one account. <.link patch={~p"/admin/reports"}>All reports</.link>
      </p>

      <div id="reports-queue" class="panel roster">
        <section class="role-section" aria-labelledby="reports-heading">
          <div class="role-section-head">
            <h3 id="reports-heading">{scope_heading(@scope)}</h3>
            <span class="muted count">{@report_summary}</span>
            <span class="muted role-section-hint">
              Newest first · a report expires two years after it was sent
            </span>
          </div>
          <p :if={@reports_empty} class="muted role-section-empty">{empty_copy(@scope)}</p>
          <div class="row-list" id="report-rows" phx-update="stream">
            <div
              :for={{dom_id, report} <- @streams.reports}
              id={dom_id}
              class="row member-row report-row"
            >
              <.person_mark user={report.reported_user} />
              <div class="member-copy">
                <div class="row-title">
                  {report.reported_user.display_name}
                  <.pill
                    :if={not report.handled and report.reported_user.open_report_count > 1}
                    variant={:cyan}
                  >
                    {report.reported_user.open_report_count} open
                  </.pill>
                  <.pill :if={User.suspended?(report.reported_user)} variant={:magenta}>
                    Suspended {format_date(report.reported_user.suspended_at)}
                  </.pill>
                </div>
                <div class="meta report-meta">
                  <.reason_pill reason={report.reason} />
                  <span>by <strong>{report.reporter.display_name}</strong></span>
                  <span>· <.source_label source={report.source} type={report.source_type} /></span>
                  <span>· {format_datetime(report.inserted_at)}</span>
                  <span :if={report.handled}>
                    · Handled by {handled_by_name(report)} {format_date(report.handled_at)}
                  </span>
                </div>
                <p :if={report.details} class="report-quote">“{report.details}”</p>
                <p :if={is_nil(report.details)} class="report-quote muted">No details</p>
              </div>
              <div class="account-row-actions">
                <.button
                  id={"review-#{report.id}"}
                  phx-click="review"
                  phx-value-id={report.id}
                  aria-expanded={@review != nil && @review.report.id == report.id}
                >
                  Review
                </.button>
                <.report_row_menu report={report} current_user={@current_user} />
              </div>
              <.review_card
                :if={@review && @review.report.id == report.id}
                review={@review}
                current_user={@current_user}
              />
            </div>
          </div>
        </section>
      </div>

      <.account_action_dialog :if={@action} action={@action} />
    </Layouts.app>
    """
  end

  attr :report, :map, required: true
  attr :current_user, :map, required: true

  defp report_row_menu(assigns) do
    assigns =
      assign(assigns,
        can_suspend: Ash.can?({assigns.report.reported_user, :suspend}, assigns.current_user),
        label: "Manage #{assigns.report.reported_user.display_name}",
        menu_id: "report-menu-#{assigns.report.id}"
      )

    ~H"""
    <div class="member-menu">
      <button
        type="button"
        id={"#{@menu_id}-trigger"}
        class="icon-pill member-menu-trigger"
        popovertarget={@menu_id}
        aria-label={@label}
        aria-haspopup="menu"
      >
        <.icon name="hero-ellipsis-horizontal" class="size-4" />
      </button>
      <div
        id={@menu_id}
        class="row-menu"
        popover="auto"
        role="menu"
        aria-label={@label}
        phx-hook="PopoverMenu"
      >
        <.link
          navigate={users_link(@report.reported_user)}
          class="row-menu-item"
          role="menuitem"
        >
          <.icon name="hero-user" class="size-4 row-menu-icon" /> Open in Users
        </.link>
        <button
          :if={@can_suspend}
          type="button"
          id={"suspend-#{@report.id}"}
          class="row-menu-item is-danger"
          role="menuitem"
          phx-click="open_action"
          phx-value-id={@report.reported_user.id}
          popovertarget={@menu_id}
          popovertargetaction="hide"
        >
          <.icon name="hero-no-symbol" class="size-4 row-menu-icon" /> Suspend account
        </button>
        <hr :if={not @report.handled} class="row-menu-divider" role="separator" />
        <button
          :if={not @report.handled}
          type="button"
          id={"handle-#{@report.id}"}
          class="row-menu-item"
          role="menuitem"
          phx-click="mark_handled"
          phx-value-id={@report.id}
          popovertarget={@menu_id}
          popovertargetaction="hide"
        >
          <.icon name="hero-check-circle" class="size-4 row-menu-icon" /> Mark handled
        </button>
      </div>
    </div>
    """
  end

  attr :review, :map, required: true
  attr :current_user, :map, required: true

  defp review_card(assigns) do
    report = assigns.review.report

    assigns =
      assign(assigns,
        report: report,
        user: report.reported_user,
        can_suspend: Ash.can?({report.reported_user, :suspend}, assigns.current_user)
      )

    ~H"""
    <div class="review-card" id={"review-card-#{@report.id}"}>
      <p class="review-lead">
        <strong>Reported by {@report.reporter.display_name}</strong>
        on {format_datetime(@report.inserted_at)},
        <.source_sentence source={@report.source} type={@report.source_type} />.
      </p>
      <div class="review-facts review-facts-3">
        <div>
          <p class="review-key">What's wrong</p>
          <p class="review-value">{reason_label(@report.reason)}</p>
        </div>
        <div>
          <p class="review-key">Details</p>
          <p class="review-value">{@report.details || "No details"}</p>
        </div>
        <div>
          <p class="review-key">Account</p>
          <p class="review-value">
            {account_status(@user)}
            <small>
              {@user.email} · <.link navigate={users_link(@user)}>Open in Users</.link>
            </small>
          </p>
        </div>
      </div>
      <div>
        <p class="review-key">Also open on this account</p>
        <div class="review-flagged">
          <p :if={@review.others == []} class="muted review-flagged-empty">
            No other open reports.
          </p>
          <div :for={other <- @review.others} class="review-flagged-row">
            <div>
              <div class="row-title">
                <.reason_pill reason={other.reason} />
                {other.reporter.display_name}
              </div>
              <div class="meta">
                <.source_label source={other.source} type={other.source_type} />
                · {other.details || "no details"}
              </div>
            </div>
            <span class="muted">{format_date(other.inserted_at)}</span>
          </div>
        </div>
      </div>
      <div class="review-foot">
        <p class="muted">
          Mark handled closes this report only. Suspending is your call, never automatic. Report details and reporter identities are visible only to huddlz staff; no report notification is sent to the reported person.
        </p>
        <div class="review-actions">
          <button type="button" class="link-btn" phx-click="collapse_review">Collapse</button>
          <.button
            :if={@can_suspend}
            id={"review-suspend-#{@report.id}"}
            phx-click="open_action"
            phx-value-id={@user.id}
          >
            <.icon name="hero-no-symbol" class="size-4" /> Suspend account
          </.button>
          <.button
            :if={@report.handled}
            id={"review-reopen-#{@report.id}"}
            phx-click="reopen"
            phx-value-id={@report.id}
            phx-disable-with="Reopening..."
          >
            Reopen
          </.button>
          <.button
            :if={not @report.handled}
            id={"review-handle-#{@report.id}"}
            variant={:primary}
            phx-click="mark_handled"
            phx-value-id={@report.id}
          >
            <.icon name="hero-check-circle" class="size-4" /> Mark handled
          </.button>
        </div>
      </div>
    </div>
    """
  end

  attr :reason, :atom, required: true

  defp reason_pill(assigns) do
    ~H"""
    <.pill variant={if @reason == :spam, do: :warn, else: :muted}>{reason_label(@reason)}</.pill>
    """
  end

  attr :source, :any, required: true
  attr :type, :atom, required: true

  defp source_label(%{source: nil} = assigns) do
    ~H"""
    <span>from {closed_door(@type)}</span>
    """
  end

  defp source_label(assigns) do
    ~H"""
    <span>from <.link navigate={source_path(@source)}>{@source.name}</.link></span>
    """
  end

  attr :source, :any, required: true
  attr :type, :atom, required: true

  defp source_sentence(%{source: nil} = assigns) do
    ~H"""
    <span>from {closed_door(@type)}</span>
    """
  end

  defp source_sentence(%{type: :huddl} = assigns) do
    ~H"""
    <span>from the huddl page for <.link navigate={source_path(@source)}>{@source.name}</.link></span>
    """
  end

  defp source_sentence(assigns) do
    ~H"""
    <span>from the members of <.link navigate={source_path(@source)}>{@source.name}</.link></span>
    """
  end

  defp source_path(%{kind: :group, group_slug: slug}), do: ~p"/groups/#{slug}"

  defp source_path(%{kind: :huddl, id: id, group_slug: slug}),
    do: ~p"/groups/#{slug}/huddlz/#{id}"

  # ── copy ────────────────────────────────────────────────────────────

  defp scope_heading(:open), do: "Open"
  defp scope_heading(:handled), do: "Handled"

  defp empty_copy(:open), do: "Nothing to review."
  defp empty_copy(:handled), do: "Nothing has been handled yet."

  defp summary(reports) do
    accounts = reports |> Enum.map(& &1.reported_user_id) |> Enum.uniq() |> length()
    "#{plural(length(reports), "report")} · #{plural(accounts, "account")}"
  end

  defp plural(1, noun), do: "1 #{noun}"
  defp plural(n, noun), do: "#{n} #{noun}s"

  defp reason_label(:spam), do: "Spam or advertising"
  defp reason_label(:other), do: "Other"

  defp closed_door(:huddl), do: "a huddl you cannot open"
  defp closed_door(:group), do: "a group you cannot open"
  defp closed_door(_type), do: "somewhere no longer available"

  defp account_status(%User{suspended_at: %DateTime{} = at} = user),
    do: "Suspended #{format_date(at)} by #{suspended_by_name(user)}"

  defp account_status(user), do: "Active · joined #{format_date(user.inserted_at)}"

  defp suspended_by_name(%{suspended_by: %User{display_name: name}}), do: name
  defp suspended_by_name(_user), do: "an administrator"

  defp handled_by_name(%{handled_by: %User{display_name: name}}), do: name
  defp handled_by_name(_report), do: "an administrator"

  defp users_link(%User{suspended_at: %DateTime{}} = user),
    do: ~p"/admin/users?scope=suspended&q=#{user.email}"

  defp users_link(user), do: ~p"/admin/users?q=#{user.email}"

  defp format_date(%DateTime{} = at), do: Calendar.strftime(at, "%b %-d, %Y")
  defp format_date(_), do: "—"

  defp format_datetime(%DateTime{} = at), do: Calendar.strftime(at, "%b %-d, %Y, %-I:%M %p UTC")
  defp format_datetime(_), do: "—"
end
