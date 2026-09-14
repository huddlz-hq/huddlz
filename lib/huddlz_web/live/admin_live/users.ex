defmodule HuddlzWeb.AdminLive.Users do
  @moduledoc """
  Account administration at `/admin/users`: everyone with an account as a
  roster, one menu per person (view as, administrator role, suspension),
  and the Suspended view, which is the review queue for suspensions with
  the restoration control.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, Huddl}
  alias HuddlzWeb.Layouts
  alias Phoenix.LiveView.JS

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :admin_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:search_query, "")
     |> assign(:action, nil)
     |> assign(:review, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = if params["scope"] == "suspended", do: :suspended, else: :accounts
    query = String.trim(params["q"] || "")

    {:noreply,
     socket
     |> assign(:scope, scope)
     |> assign(:search_query, query)
     |> assign(:review, nil)
     |> load_people()}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: users_path(socket.assigns.scope, String.trim(query)))}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: users_path(socket.assigns.scope, ""))}
  end

  def handle_event("review", %{"id" => id}, socket) do
    review =
      if socket.assigns.review && socket.assigns.review.user.id == id,
        do: nil,
        else: build_review(id, socket.assigns.current_user)

    {:noreply, assign(socket, :review, review)}
  end

  def handle_event("collapse_review", _params, socket) do
    {:noreply, assign(socket, :review, nil)}
  end

  def handle_event("open_action", %{"id" => id, "action" => action}, socket) do
    case Ash.get(User, id, actor: socket.assigns.current_user) do
      {:ok, user} -> {:noreply, assign(socket, :action, build_action(action, user, socket))}
      _ -> {:noreply, put_flash(socket, :error, "User not found")}
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
      nil -> {:noreply, socket}
      action -> confirm(action, params["form"] || %{}, socket)
    end
  end

  # ── actions ─────────────────────────────────────────────────────────

  defp build_action("suspend", user, socket) do
    form =
      AshPhoenix.Form.for_update(user, :suspend, actor: socket.assigns.current_user, as: "form")

    %{type: :suspend, user: user, form: to_form(form)}
  end

  defp build_action("restore", user, socket) do
    form =
      AshPhoenix.Form.for_update(user, :restore, actor: socket.assigns.current_user, as: "form")

    %{type: :restore, user: user, form: to_form(form)}
  end

  defp build_action(role, user, _socket) when role in ["make_admin", "remove_admin"] do
    %{type: String.to_existing_atom(role), user: user, form: nil}
  end

  defp confirm(%{type: type, user: user, form: form}, params, socket)
       when type in [:suspend, :restore] do
    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:action, nil)
         |> assign(:review, nil)
         |> put_flash(:info, outcome(type, updated))
         |> load_people()}

      {:error, form} ->
        {:noreply, assign(socket, :action, %{type: type, user: user, form: form})}
    end
  end

  defp confirm(%{type: type, user: user}, _params, socket) do
    role = if type == :make_admin, do: :admin, else: :user

    case Accounts.update_role(user, role, actor: socket.assigns.current_user) do
      {:ok, _updated} ->
        {:noreply,
         socket
         |> assign(:action, nil)
         |> put_flash(:info, "User role updated successfully")
         |> load_people()}

      {:error, _reason} ->
        {:noreply,
         socket |> assign(:action, nil) |> put_flash(:error, "Failed to update user role")}
    end
  end

  defp outcome(:suspend, user), do: "#{user.display_name} is suspended"
  defp outcome(:restore, user), do: "#{user.display_name} is restored"

  # ── data ────────────────────────────────────────────────────────────

  defp load_people(%{assigns: %{scope: scope, search_query: query}} = socket) do
    actor = socket.assigns.current_user
    suspended? = scope == :suspended

    people =
      Accounts.search_by_email!(query, %{suspended: suspended?},
        actor: actor,
        load: [:current_profile_picture_url, :is_admin, :suspended_by],
        query: [sort: [display_name: :asc]]
      )

    active_count = count(actor, query, false)
    suspended_count = count(actor, query, true)

    {admins, others} = Enum.split_with(people, &User.admin?/1)

    socket
    |> assign(:people, people)
    |> assign(:admins, admins)
    |> assign(:others, others)
    |> assign(:active_count, active_count)
    |> assign(:suspended_count, suspended_count)
  end

  defp count(actor, query, suspended?) do
    User
    |> Ash.Query.for_read(:search_by_email, %{email: query, suspended: suspended?}, actor: actor)
    |> Ash.count!()
  end

  # Account administration grants no additional access to community records.
  defp build_review(user_id, actor) do
    user = Ash.get!(User, user_id, actor: actor, load: [:suspended_by])

    groups =
      Group
      |> Ash.Query.for_read(:read_with_archived, %{}, actor: actor)
      |> Ash.Query.filter(owner_id == ^user_id and is_nil(archived_at))
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!()

    huddlz =
      Huddl
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(
        (creator_id == ^user_id or group.owner_id == ^user_id) and
          lifecycle_state in [:draft, :published] and ends_at > now()
      )
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.read!()

    %{user: user, groups: groups, huddlz: huddlz}
  end

  defp users_path(:suspended, ""), do: ~p"/admin/users?scope=suspended"
  defp users_path(:suspended, query), do: ~p"/admin/users?scope=suspended&q=#{query}"
  defp users_path(:accounts, ""), do: ~p"/admin/users"
  defp users_path(:accounts, query), do: ~p"/admin/users?q=#{query}"

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
      active_admin_section={:users}
    >
      <div class="page-head">
        <div>
          <h1>Users</h1>
          <p>
            Everyone with a huddlz account. Suspended accounts leave this list and every member list; review them under Suspended.
          </p>
        </div>
      </div>

      <div class="admin-users-bar">
        <div class="chip-group">
          <.chip
            patch={users_path(:accounts, @search_query)}
            active={@scope == :accounts}
            count={@active_count}
          >
            Accounts
          </.chip>
          <.chip
            patch={users_path(:suspended, @search_query)}
            active={@scope == :suspended}
            count={@suspended_count}
          >
            Suspended
          </.chip>
        </div>
        <form phx-submit="search" class="admin-search">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search by email"
            aria-label="Search by email"
            class="form-input"
          />
          <button type="submit" class="btn-secondary">Search</button>
          <button
            :if={@search_query != ""}
            type="button"
            class="btn-secondary"
            phx-click="clear_search"
          >
            Clear
          </button>
        </form>
      </div>

      <div id="accounts-roster" class="panel roster">
        <%= if @scope == :accounts do %>
          <.roster_section
            :if={@admins != []}
            id="role-admins"
            heading="Administrators"
            count={length(@admins)}
            people={@admins}
            current_user={@current_user}
          />
          <.roster_section
            id="role-people"
            heading="People"
            count={length(@others)}
            people={@others}
            current_user={@current_user}
            empty="No accounts match."
          />
        <% else %>
          <section class="role-section" aria-labelledby="role-suspended-heading">
            <div class="role-section-head">
              <h3 id="role-suspended-heading">Suspended</h3>
              <span class="muted count">{length(@people)}</span>
              <span class="muted role-section-hint">Most recent first · status and reason stay until restoration</span>
            </div>
            <div class="row-list">
              <p :if={@people == []} class="muted role-section-empty">Nobody is suspended.</p>
              <div
                :for={user <- sort_suspended(@people)}
                id={"user-#{user.id}"}
                class="row member-row"
              >
                <.person_mark user={user} />
                <div class="member-copy">
                  <div class="row-title">{user.display_name}</div>
                  <div class="meta">{suspension_meta(user)}</div>
                </div>
                <.account_menu user={user} current_user={@current_user} scope={:suspended} />
                <.review_card :if={@review && @review.user.id == user.id} review={@review} />
              </div>
            </div>
          </section>
        <% end %>
      </div>

      <.account_action_dialog :if={@action} action={@action} />
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :heading, :string, required: true
  attr :count, :integer, required: true
  attr :people, :list, required: true
  attr :current_user, :map, required: true
  attr :empty, :string, default: nil

  defp roster_section(assigns) do
    ~H"""
    <section class="role-section" aria-labelledby={"#{@id}-heading"}>
      <div class="role-section-head">
        <h3 id={"#{@id}-heading"}>{@heading}</h3>
        <span class="muted count">{@count}</span>
      </div>
      <div class="row-list">
        <p :if={@people == [] and @empty} class="muted role-section-empty">{@empty}</p>
        <div :for={user <- @people} id={"user-#{user.id}"} class="row member-row">
          <.person_mark user={user} />
          <div class="member-copy">
            <div class="row-title">
              {user.display_name}
              <.pill :if={User.admin?(user)} variant={:magenta}>Admin</.pill>
              <.pill :if={user.id == @current_user.id} variant={:cyan}>You</.pill>
            </div>
            <div class="meta">{user.email} · Joined {format_date(user.inserted_at)}</div>
          </div>
          <.account_menu user={user} current_user={@current_user} scope={:accounts} />
        </div>
      </div>
    </section>
    """
  end

  attr :user, :map, required: true
  attr :current_user, :map, required: true
  attr :scope, :atom, required: true

  defp account_menu(assigns) do
    assigns =
      assign(assigns,
        can_view_as: viewable_as?(assigns.user, assigns.current_user),
        can_change_role: Ash.can?({assigns.user, :update_role}, assigns.current_user),
        can_suspend: Ash.can?({assigns.user, :suspend}, assigns.current_user),
        can_restore: Ash.can?({assigns.user, :restore}, assigns.current_user),
        label: "Manage #{assigns.user.display_name}",
        menu_id: "account-menu-#{assigns.user.id}"
      )

    ~H"""
    <div :if={@can_view_as or @can_change_role or @can_suspend or @can_restore} class="member-menu">
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
        <%= if @scope == :accounts do %>
          <.link
            :if={@can_view_as}
            href={~p"/admin/impersonations/#{@user.id}"}
            method="post"
            class="row-menu-item"
            role="menuitem"
            aria-label={"View as #{@user.email}"}
          >
            <.icon name="hero-eye" class="size-4 row-menu-icon" /> View as
          </.link>
          <.account_menu_item
            :if={@can_change_role and not User.admin?(@user)}
            id={"make-admin-#{@user.id}"}
            menu={@menu_id}
            user={@user}
            action="make_admin"
            icon="hero-shield-check"
          >
            Make an administrator
          </.account_menu_item>
          <.account_menu_item
            :if={@can_change_role and User.admin?(@user)}
            id={"remove-admin-#{@user.id}"}
            menu={@menu_id}
            user={@user}
            action="remove_admin"
            icon="hero-shield-exclamation"
          >
            Remove as administrator
          </.account_menu_item>
          <.account_menu_item
            :if={@can_suspend}
            id={"suspend-#{@user.id}"}
            menu={@menu_id}
            user={@user}
            action="suspend"
            icon="hero-no-symbol"
            danger
          >
            Suspend account
          </.account_menu_item>
        <% else %>
          <button
            type="button"
            id={"review-#{@user.id}"}
            class="row-menu-item"
            role="menuitem"
            phx-click="review"
            phx-value-id={@user.id}
            popovertarget={@menu_id}
            popovertargetaction="hide"
          >
            <.icon name="hero-document-magnifying-glass" class="size-4 row-menu-icon" /> Review
          </button>
          <.account_menu_item
            :if={@can_restore}
            id={"restore-#{@user.id}"}
            menu={@menu_id}
            user={@user}
            action="restore"
            icon="hero-arrow-uturn-left"
          >
            Restore account
          </.account_menu_item>
        <% end %>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :menu, :string, required: true
  attr :user, :map, required: true
  attr :action, :string, required: true
  attr :icon, :string, required: true
  attr :danger, :boolean, default: false
  slot :inner_block, required: true

  defp account_menu_item(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      class={["row-menu-item", @danger && "is-danger"]}
      role="menuitem"
      phx-click="open_action"
      phx-value-id={@user.id}
      phx-value-action={@action}
      popovertarget={@menu}
      popovertargetaction="hide"
    >
      <.icon name={@icon} class="size-4 row-menu-icon" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :review, :map, required: true

  defp review_card(assigns) do
    ~H"""
    <div class="review-card" id={"review-card-#{@review.user.id}"}>
      <p class="review-lead">
        <strong>Shown to everyone else as “Suspended account”.</strong>
        The original name and email are kept here and in participation history only.
      </p>
      <div class="review-facts">
        <div>
          <p class="review-key">Suspended</p>
          <p class="review-value">
            {format_datetime(@review.user.suspended_at)}
            <small>by {suspended_by_name(@review.user)}</small>
          </p>
        </div>
        <div>
          <p class="review-key">Reason</p>
          <p class="review-value">{@review.user.suspension_reason}</p>
        </div>
      </div>
      <div>
        <p class="review-key">Flagged for review · groups they own</p>
        <div class="review-flagged">
          <p :if={@review.groups == []} class="muted review-flagged-empty">No groups to show.</p>
          <div :for={group <- @review.groups} class="review-flagged-row">
            <div>
              <div class="row-title">
                {group.name}
                <.pill variant={:warn}>Needs a look</.pill>
              </div>
              <div class="meta">
                {if group.is_public, do: "Public", else: "Private"}
              </div>
            </div>
            <.link navigate={~p"/groups/#{group.slug}"}>Open group</.link>
          </div>
        </div>
        <p class="muted review-note">
          Only groups you can normally access are shown.
        </p>
      </div>
      <div>
        <p class="review-key">Flagged for review · upcoming huddlz</p>
        <div class="review-flagged">
          <p :if={@review.huddlz == []} class="muted review-flagged-empty">
            No upcoming huddlz to show.
          </p>
          <div :for={huddl <- @review.huddlz} class="review-flagged-row">
            <div>
              <div class="row-title">
                {huddl.title}
                <.pill variant={:warn}>Needs a look</.pill>
              </div>
              <div class="meta">
                {huddl.group.name} · {format_date(huddl.starts_at)}
              </div>
            </div>
            <.link navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}>Open huddl</.link>
          </div>
        </div>
        <p class="muted review-note">
          Only huddlz you can normally access are shown.
          Groups and huddlz stay as they are. Nothing is hidden or removed on their behalf; an administrator decides each one.
        </p>
      </div>
      <div class="review-foot">
        <p class="muted">
          Restore only when the suspension was a mistake. They can sign in again with a fresh session; revoked sessions and API keys stay revoked, and released spots are not rebooked.
        </p>
        <div class="review-actions">
          <button type="button" class="link-btn" phx-click="collapse_review">Collapse</button>
          <.button
            id={"review-restore-#{@review.user.id}"}
            phx-click="open_action"
            phx-value-id={@review.user.id}
            phx-value-action="restore"
          >
            Restore account
          </.button>
        </div>
      </div>
    </div>
    """
  end

  attr :action, :map, required: true

  defp account_action_dialog(assigns) do
    ~H"""
    <.modal id="account-action-dialog" show on_cancel={JS.push("cancel_action")}>
      <div class="pr-8">
        <h2 id="account-action-dialog-title" class="text-xl font-bold text-base-content">
          {action_title(@action)}
        </h2>
        <p class="mt-3 text-sm leading-6 text-base-content/70">{action_description(@action)}</p>
        <ul :if={action_effects(@action.type) != []} class="leave-confirm-list">
          <li :for={effect <- action_effects(@action.type)}>{effect}</li>
        </ul>
      </div>

      <.form
        for={@action.form || %{}}
        id="account-action-form"
        phx-submit="confirm_action"
        phx-change="validate_action"
        class="mt-6"
      >
        <.textarea
          :if={@action.type == :suspend}
          field={@action.form[:reason]}
          id="suspend-reason"
          label="Reason"
          rows="3"
          placeholder="What happened, in a sentence or two."
          help="Kept with the account and shown only to administrators. Reports and reporters stay out of the email."
        />

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <.button id="account-action-cancel" phx-click="cancel_action">Cancel</.button>
          <.button
            id="account-action-confirm"
            type="submit"
            variant={if @action.type == :suspend, do: :destructive, else: :primary}
            phx-disable-with="Saving..."
          >
            {action_confirm_label(@action.type)}
          </.button>
        </div>
      </.form>
    </.modal>
    """
  end

  # ── copy ────────────────────────────────────────────────────────────

  defp action_title(%{type: :suspend, user: user}), do: "Suspend #{user.display_name}?"
  defp action_title(%{type: :restore, user: user}), do: "Restore #{user.display_name}?"

  defp action_title(%{type: :make_admin, user: user}),
    do: "Make #{user.display_name} an administrator?"

  defp action_title(%{type: :remove_admin, user: user}),
    do: "Remove #{user.display_name} as an administrator?"

  defp action_description(%{type: :suspend}),
    do:
      "Their access ends now, on every device and API key, and stays off until an administrator restores it."

  defp action_description(%{type: :restore}),
    do:
      "Only for a suspension that was a mistake. Proof that a person is at the keyboard is not enough on its own."

  defp action_description(%{type: :make_admin}),
    do:
      "Administrators manage accounts and see the platform overview. Their group roles do not change."

  defp action_description(%{type: :remove_admin}),
    do: "They keep their account and group roles and lose the admin area."

  defp action_effects(:suspend),
    do: [
      "Upcoming RSVP and waitlist spots are released. History is kept.",
      "Other members see “Suspended account” instead of their name and picture.",
      "Their groups and huddlz stay and are flagged for review.",
      "They get one email with the support address. Nothing from this form is in it."
    ]

  defp action_effects(:restore),
    do: [
      "They can sign in again from scratch. Old sessions and API keys stay revoked.",
      "Their name and picture come back everywhere.",
      "Released RSVP and waitlist spots are not rebooked."
    ]

  defp action_effects(_type), do: []

  defp action_confirm_label(:suspend), do: "Suspend account"
  defp action_confirm_label(:restore), do: "Restore account"
  defp action_confirm_label(:make_admin), do: "Make an administrator"
  defp action_confirm_label(:remove_admin), do: "Remove as administrator"

  # Administrators view huddlz as other people, never as each other.
  defp viewable_as?(%{role: :admin}, _admin), do: false
  defp viewable_as?(%{id: id}, %{id: id}), do: false
  defp viewable_as?(_user, _admin), do: true

  defp sort_suspended(people), do: Enum.sort_by(people, & &1.suspended_at, {:desc, DateTime})

  defp suspension_meta(user) do
    "#{user.email} · Suspended #{format_date(user.suspended_at)} by #{suspended_by_name(user)} · #{user.suspension_reason}"
  end

  defp suspended_by_name(%{suspended_by: %User{display_name: name}}), do: name
  defp suspended_by_name(_user), do: "an administrator"

  defp format_date(%DateTime{} = at), do: Calendar.strftime(at, "%b %-d, %Y")
  defp format_date(_), do: "—"

  defp format_datetime(%DateTime{} = at), do: Calendar.strftime(at, "%b %-d, %Y, %-I:%M %p UTC")
  defp format_datetime(_), do: "—"
end
