defmodule HuddlzWeb.OrganizeLive do
  @moduledoc """
  Per-group organizer workspace. Each owned group is its own workspace,
  reached at `/organize/:group_slug` and rendered inside `<Layouts.app>`
  with the group's row in the sidebar `sb-orgs` section expanded.

  Routes:

    * `/organize` — landing picker (owned groups + create CTA, or empty state)
    * `/organize/:group_slug` — overview (KPIs + upcoming huddlz)
    * `/organize/:group_slug/huddlz` — huddlz list, live/past filter
    * `/organize/:group_slug/members` — roster grouped by role
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.MembershipEvents
  alias HuddlzWeb.Layouts

  @group_loads [:member_count]
  @huddl_loads [:rsvp_count, :status, :group]
  @upcoming_loads [:rsvp_count, :group]
  @member_role_order [:owner, :organizer, :member]
  @upcoming_preview_limit 5

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Organizer workspace")
     |> assign(:group, nil)
     |> assign(:owned_groups, [])
     |> assign(:huddlz_list, [])
     |> assign(:huddlz_filter, :live)
     |> assign(:upcoming_huddlz, [])
     |> assign(:open_rsvps, 0)
     |> assign(:members, [])
     |> assign(:subscribed_group_id, nil)
     |> assign(:pending_member_action, nil)
     |> assign(:ownership_confirmation, "")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_user
    action = socket.assigns.live_action

    socket =
      socket
      |> assign(:huddlz_filter, parse_huddlz_filter(params["filter"]))
      |> load_action(action, params, user)

    {:noreply, socket}
  end

  defp load_action(socket, :index, _params, user) do
    owned_groups = Ash.load!(socket.assigns.sidebar_owned_groups, @group_loads, actor: user)

    socket
    |> assign(:group, nil)
    |> assign(:owned_groups, owned_groups)
  end

  defp load_action(socket, action, %{"group_slug" => slug}, user) do
    case load_group(slug, user) do
      {:ok, group} ->
        socket
        |> subscribe_to_membership_changes(group)
        |> assign(:group, group)
        |> assign(:page_title, "#{group.name} · Organizer")
        |> load_section(action, group, user)

      :error ->
        socket
        |> put_flash(:error, "That group doesn't exist, or you don't organize it.")
        |> push_navigate(to: ~p"/organize")
    end
  end

  defp load_section(socket, :overview, group, user) do
    upcoming = list_upcoming_huddlz(group, user)
    open_rsvps = Enum.reduce(upcoming, 0, &(&1.rsvp_count + &2))

    socket
    |> assign(:upcoming_huddlz, upcoming)
    |> assign(:open_rsvps, open_rsvps)
  end

  defp load_section(socket, :huddlz, group, user) do
    state = socket.assigns.huddlz_filter
    huddlz = list_group_huddlz(group, state, user)
    assign(socket, :huddlz_list, huddlz)
  end

  defp load_section(socket, :members, group, user) do
    members = list_group_members(group, user)
    assign(socket, :members, members)
  end

  defp load_group(slug, user) do
    case Communities.get_group_for_organize(slug, actor: user, load: @group_loads) do
      {:ok, %Huddlz.Communities.Group{} = group} -> {:ok, group}
      _ -> :error
    end
  end

  defp list_upcoming_huddlz(group, user) do
    Communities.list_upcoming_huddlz!(
      actor: user,
      load: @upcoming_loads,
      query: [filter: [group_id: group.id]]
    )
  end

  defp list_group_huddlz(group, state, user) do
    Communities.huddlz_for_organizer!(state,
      actor: user,
      load: @huddl_loads,
      query: [
        filter: [group_id: group.id],
        sort: [starts_at: state_sort_dir(state)]
      ]
    )
  end

  defp list_group_members(group, user) do
    Communities.get_by_group!(group.id,
      actor: user,
      load: :user,
      query: [sort: [created_at: :asc]]
    )
  end

  defp subscribe_to_membership_changes(socket, group) do
    if connected?(socket) and socket.assigns.subscribed_group_id != group.id do
      :ok = MembershipEvents.subscribe(group.id)
      assign(socket, :subscribed_group_id, group.id)
    else
      socket
    end
  end

  defp parse_huddlz_filter("past"), do: :past
  defp parse_huddlz_filter(_), do: :live

  defp state_sort_dir(:past), do: :desc
  defp state_sort_dir(_), do: :asc

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active_group_slug={@group && @group.slug}
      active_organize_section={active_section(@live_action)}
    >
      <%= case @live_action do %>
        <% :index -> %>
          <.picker_view groups={@owned_groups} />
        <% :overview -> %>
          <.overview_view
            group={@group}
            upcoming_huddlz={@upcoming_huddlz}
            open_rsvps={@open_rsvps}
          />
        <% :huddlz -> %>
          <.huddlz_view group={@group} huddlz={@huddlz_list} filter={@huddlz_filter} />
        <% :members -> %>
          <.members_view group={@group} members={@members} current_user={@current_user} />
      <% end %>

      <.member_action_dialog
        :if={@pending_member_action}
        action={@pending_member_action}
        group={@group}
        ownership_confirmation={@ownership_confirmation}
      />
    </Layouts.app>
    """
  end

  defp active_section(:overview), do: :overview
  defp active_section(:huddlz), do: :huddlz
  defp active_section(:members), do: :members
  defp active_section(_), do: nil

  # ─────────────────────────────────────────  PICKER (/organize)  ───
  attr :groups, :list, required: true

  defp picker_view(assigns) do
    ~H"""
    <div class="page-head">
      <div>
        <h1>Organizer workspace</h1>
        <p>Pick a group to manage, or start a new one.</p>
      </div>
      <div :if={@groups != []} class="actions">
        <a class="btn-primary" href={~p"/groups/new"}>+ Create group</a>
      </div>
    </div>

    <%= if @groups == [] do %>
      <div class="panel">
        <div class="panel-head">
          <h2>Get started</h2>
        </div>
        <p class="muted">
          You don't organize any groups yet. Create a group to start hosting huddlz —
          each group gets its own workspace here.
        </p>
        <div class="panel-cta">
          <a class="btn-primary" href={~p"/groups/new"}>Create your first group</a>
        </div>
      </div>
    <% else %>
      <div class="panel">
        <div class="panel-head">
          <h2>Your groups</h2>
          <span class="panel-sub">{group_count_label(length(@groups))}</span>
        </div>
        <div class="row-list">
          <a
            :for={group <- @groups}
            class="row row-split"
            href={~p"/organize/#{group.slug}"}
          >
            <div>
              <div class="row-title">{group.name}</div>
              <div class="meta">
                {member_label(group.member_count)} · {visibility_label(group.is_public)}
              </div>
            </div>
            <span class="pill">Open →</span>
          </a>
        </div>
      </div>
    <% end %>
    """
  end

  # ─────────────────────────────────────────  OVERVIEW  ───
  attr :group, :map, required: true
  attr :upcoming_huddlz, :list, required: true
  attr :open_rsvps, :integer, required: true

  defp overview_view(assigns) do
    assigns =
      assigns
      |> assign(:preview_limit, @upcoming_preview_limit)
      |> assign(:upcoming_count, length(assigns.upcoming_huddlz))

    ~H"""
    <div class="page-head">
      <div>
        <h1>{@group.name}</h1>
        <p>A scannable summary of this group's huddlz and members.</p>
      </div>
      <div class="actions">
        <a class="btn-secondary" href={~p"/groups/#{@group.slug}/edit"}>Edit group</a>
        <a class="btn-primary" href={~p"/groups/#{@group.slug}/huddlz/new"}>
          + Create huddl
        </a>
      </div>
    </div>

    <div class="kpis">
      <div class="kpi">
        <div class="label">Members</div>
        <div class="value">{@group.member_count}</div>
        <div class="delta muted">In this group</div>
      </div>
      <div class="kpi">
        <div class="label">Upcoming</div>
        <div class="value">{@upcoming_count}</div>
        <div class="delta muted">Huddlz scheduled</div>
      </div>
      <div class="kpi">
        <div class="label">Open RSVPs</div>
        <div class="value">{@open_rsvps}</div>
        <div class="delta muted">Across upcoming huddlz</div>
      </div>
      <div class="kpi">
        <div class="label">Visibility</div>
        <div class="value">{visibility_label(@group.is_public)}</div>
        <div class="delta muted">{visibility_subtitle(@group.is_public)}</div>
      </div>
    </div>

    <div class="panel">
      <div class="panel-head">
        <div>
          <h2>Upcoming huddlz</h2>
          <div class="panel-sub">Next on the calendar</div>
        </div>
        <.link
          :if={@upcoming_count > @preview_limit}
          navigate={~p"/organize/#{@group.slug}/huddlz"}
          class="pill"
        >
          View all
        </.link>
      </div>

      <%= if @upcoming_huddlz == [] do %>
        <p class="muted">No upcoming huddlz right now. Create one to get started.</p>
      <% else %>
        <div class="row-list">
          <div
            :for={huddl <- Enum.take(@upcoming_huddlz, @preview_limit)}
            class="row row-split"
          >
            <div>
              <div class="row-title">
                <.link navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}>
                  {huddl.title}
                </.link>
              </div>
              <div class="meta">{format_starts_at(huddl.starts_at)}</div>
            </div>
            <span class="pill">{rsvp_label(huddl.rsvp_count)}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ─────────────────────────────────────────  HUDDLZ  ───
  attr :group, :map, required: true
  attr :huddlz, :list, required: true
  attr :filter, :atom, required: true

  defp huddlz_view(assigns) do
    ~H"""
    <div class="page-head">
      <div>
        <h1>Huddlz</h1>
        <p>Every huddl in {@group.name}. Click one to manage it.</p>
      </div>
      <div class="actions">
        <a class="btn-primary" href={~p"/groups/#{@group.slug}/huddlz/new"}>
          + Schedule huddl
        </a>
      </div>
    </div>

    <div class="filters">
      <.link patch={huddlz_filter_path(@group, :live)} class={filter_chip_class(@filter == :live)}>
        Live
      </.link>
      <.link patch={huddlz_filter_path(@group, :past)} class={filter_chip_class(@filter == :past)}>
        Past
      </.link>
    </div>

    <%= if @huddlz == [] do %>
      <div class="panel">
        <div class="panel-head">
          <h2>{empty_huddlz_heading(@filter)}</h2>
        </div>
        <p class="muted">{empty_huddlz_body(@filter)}</p>
        <div :if={@filter == :live} class="panel-cta">
          <a class="btn-primary" href={~p"/groups/#{@group.slug}/huddlz/new"}>
            Create your first huddl
          </a>
        </div>
      </div>
    <% else %>
      <div class="panel">
        <div class="panel-head">
          <h2>{filter_heading(@filter)}</h2>
          <span class="panel-sub">{length(@huddlz)} total</span>
        </div>
        <div class="row-list">
          <div
            :for={huddl <- @huddlz}
            class="row row-split-two"
          >
            <div>
              <div class="row-title">
                <.link navigate={~p"/groups/#{@group.slug}/huddlz/#{huddl.id}/edit"}>
                  {huddl.title}
                </.link>
              </div>
              <div class="meta">{format_starts_at(huddl.starts_at)}</div>
            </div>
            <span class="pill">{rsvp_label(huddl.rsvp_count)}</span>
            <span class={["pill", status_pill_class(huddl.status)]}>
              {format_status(huddl.status)}
            </span>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp huddlz_filter_path(group, :past), do: ~p"/organize/#{group.slug}/huddlz?filter=past"
  defp huddlz_filter_path(group, _), do: ~p"/organize/#{group.slug}/huddlz"

  defp filter_chip_class(true), do: "chip is-active"
  defp filter_chip_class(false), do: "chip"

  defp filter_heading(:past), do: "Past huddlz"
  defp filter_heading(_), do: "Live huddlz"

  defp empty_huddlz_heading(:past), do: "No past huddlz yet"
  defp empty_huddlz_heading(_), do: "No huddlz scheduled"

  defp empty_huddlz_body(:past),
    do: "Once a huddl wraps up, it'll show here so you can revisit attendance and notes."

  defp empty_huddlz_body(_),
    do: "Schedule a huddl to start hosting. Every huddl you create for this group lands here."

  defp status_pill_class(:cancelled), do: "muted"
  defp status_pill_class(_), do: nil

  defp format_status(:upcoming), do: "Upcoming"
  defp format_status(:in_progress), do: "In progress"
  defp format_status(:past), do: "Past"
  defp format_status(:cancelled), do: "Cancelled"
  defp format_status(other) when is_atom(other), do: other |> to_string() |> String.capitalize()
  defp format_status(_), do: ""

  # ─────────────────────────────────────────  MEMBERS  ───
  attr :group, :map, required: true
  attr :members, :list, required: true
  attr :current_user, :map, required: true

  defp members_view(assigns) do
    by_role = Enum.group_by(assigns.members, & &1.role)
    grouped = Enum.map(@member_role_order, fn role -> {role, Map.get(by_role, role, [])} end)

    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <div class="page-head">
      <div>
        <h1>Members</h1>
        <p>Who's part of {@group.name}.</p>
      </div>
      <div class="actions">
        <a class="btn-secondary" href={~p"/groups/#{@group.slug}/edit"}>Edit group</a>
      </div>
    </div>

    <div class="panel">
      <div class="panel-head">
        <div>
          <h2>{member_count_heading(@group.member_count)}</h2>
          <div class="panel-sub">
            {visibility_label(@group.is_public)} group · {member_label(@group.member_count)}
          </div>
        </div>
      </div>

      <%= for {role, rows} <- @grouped do %>
        <div class="role-section">
          <div class="role-section-head">
            <h3>{role_heading(role)}</h3>
            <span :if={role != :owner} class="muted count">({length(rows)})</span>
          </div>
          <%= if rows == [] do %>
            <p class="muted role-section-empty">{role_empty_copy(role)}</p>
          <% else %>
            <div class="row-list">
              <div :for={entry <- rows} class="row row-split gap-4">
                <div>
                  <div class="row-title">{member_name(entry)}</div>
                  <div class="meta">{format_member_meta(entry)}</div>
                </div>
                <div class="flex flex-wrap items-center justify-end gap-2">
                  <span class={["pill", role_pill_class(role)]}>{role_label(role)}</span>
                  <.member_actions
                    entry={entry}
                    group={@group}
                    current_user={@current_user}
                  />
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :entry, :map, required: true
  attr :group, :map, required: true
  attr :current_user, :map, required: true

  defp member_actions(assigns) do
    assigns =
      assign(assigns,
        can_promote:
          member_action_allowed?(:promote, assigns.entry, assigns.group, assigns.current_user),
        can_demote:
          member_action_allowed?(:demote, assigns.entry, assigns.group, assigns.current_user),
        can_remove:
          member_action_allowed?(:remove, assigns.entry, assigns.group, assigns.current_user),
        can_transfer:
          member_action_allowed?(:transfer, assigns.entry, assigns.group, assigns.current_user)
      )

    ~H"""
    <div
      :if={@can_promote or @can_demote or @can_remove or @can_transfer}
      class="flex flex-wrap justify-end gap-2"
      aria-label={"Manage #{member_name(@entry)}"}
    >
      <.button
        :if={@can_promote}
        id={"promote-member-#{@entry.id}"}
        phx-click="open_member_action"
        phx-value-id={@entry.id}
        phx-value-action="promote"
        class="text-sm"
      >
        Promote
      </.button>
      <.button
        :if={@can_demote}
        id={"demote-member-#{@entry.id}"}
        phx-click="open_member_action"
        phx-value-id={@entry.id}
        phx-value-action="demote"
        class="text-sm"
      >
        Demote
      </.button>
      <.button
        :if={@can_transfer}
        id={"transfer-owner-#{@entry.id}"}
        phx-click="open_member_action"
        phx-value-id={@entry.id}
        phx-value-action="transfer"
        class="text-sm"
      >
        Transfer ownership
      </.button>
      <.button
        :if={@can_remove}
        id={"remove-member-#{@entry.id}"}
        variant={:destructive}
        phx-click="open_member_action"
        phx-value-id={@entry.id}
        phx-value-action="remove"
        class="text-sm"
      >
        Remove
      </.button>
    </div>
    """
  end

  attr :action, :map, required: true
  attr :group, :map, required: true
  attr :ownership_confirmation, :string, required: true

  defp member_action_dialog(assigns) do
    ~H"""
    <.modal
      id="member-action-dialog"
      show
      on_cancel={JS.push("cancel_member_action")}
    >
      <div class="pr-8">
        <h2 id="member-action-dialog-title" class="text-xl font-bold text-base-content">
          {member_action_title(@action)}
        </h2>
        <p class="mt-3 text-sm leading-6 text-base-content/70">
          {member_action_description(@action, @group)}
        </p>
      </div>

      <form
        id="member-action-form"
        phx-submit="confirm_member_action"
        phx-change="validate_member_action_confirmation"
        class="mt-6"
      >
        <.input
          :if={@action.type == :transfer}
          id="ownership-confirmation"
          name="confirmation"
          label={"Type #{@group.name} to confirm"}
          value={@ownership_confirmation}
          autocomplete="off"
          help="Ownership transfer changes who controls the group immediately."
        />

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <.button id="member-action-cancel" phx-click="cancel_member_action">
            Cancel
          </.button>
          <.button
            id="member-action-confirm"
            type="submit"
            variant={member_action_button_variant(@action.type)}
            disabled={@action.type == :transfer and @ownership_confirmation != to_string(@group.name)}
            phx-disable-with="Saving..."
          >
            {member_action_confirm_label(@action.type)}
          </.button>
        </div>
      </form>
    </.modal>
    """
  end

  @impl true
  def handle_event("open_member_action", %{"id" => id, "action" => action}, socket) do
    with {:ok, action_type} <- parse_member_action(action),
         %{} = member <- Enum.find(socket.assigns.members, &(&1.id == id)),
         true <-
           member_action_allowed?(
             action_type,
             member,
             socket.assigns.group,
             socket.assigns.current_user
           ) do
      {:noreply,
       socket
       |> assign(:pending_member_action, %{type: action_type, member: member})
       |> assign(:ownership_confirmation, "")}
    else
      _ -> {:noreply, put_flash(socket, :error, "That membership action is not available.")}
    end
  end

  def handle_event("cancel_member_action", _params, socket) do
    {:noreply,
     socket
     |> assign(:pending_member_action, nil)
     |> assign(:ownership_confirmation, "")}
  end

  def handle_event(
        "validate_member_action_confirmation",
        %{"confirmation" => confirmation},
        socket
      ) do
    {:noreply, assign(socket, :ownership_confirmation, confirmation)}
  end

  def handle_event("validate_member_action_confirmation", _params, socket), do: {:noreply, socket}

  def handle_event(
        "confirm_member_action",
        _params,
        %{assigns: %{pending_member_action: nil}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("confirm_member_action", _params, socket) do
    action = socket.assigns.pending_member_action

    if confirmation_valid?(action.type, socket) do
      perform_member_action(socket, action)
    else
      {:noreply, put_flash(socket, :error, "Type the group name exactly to transfer ownership.")}
    end
  end

  @impl true
  def handle_info(
        {:group_membership_changed, group_id},
        %{assigns: %{group: %{id: group_id}}} = socket
      ) do
    {:noreply, refresh_after_membership_change(socket)}
  end

  def handle_info({:group_membership_changed, _group_id}, socket), do: {:noreply, socket}

  defp perform_member_action(socket, action) do
    case run_member_action(action, socket.assigns.group, socket.assigns.current_user) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> assign(:pending_member_action, nil)
         |> assign(:ownership_confirmation, "")
         |> put_flash(:info, member_action_success(action))
         |> refresh_after_membership_change()}

      :ok ->
        {:noreply,
         socket
         |> assign(:pending_member_action, nil)
         |> assign(:ownership_confirmation, "")
         |> put_flash(:info, member_action_success(action))
         |> refresh_after_membership_change()}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:pending_member_action, nil)
         |> assign(:ownership_confirmation, "")
         |> put_flash(:error, "The membership could not be updated. Please try again.")}
    end
  end

  defp run_member_action(%{type: :promote, member: member}, _group, user) do
    Communities.change_member_role(member, :organizer, actor: user)
  end

  defp run_member_action(%{type: :demote, member: member}, _group, user) do
    Communities.change_member_role(member, :member, actor: user)
  end

  defp run_member_action(%{type: :remove, member: member}, group, user) do
    Communities.remove_member(member, group.id, member.user_id, actor: user)
  end

  defp run_member_action(%{type: :transfer, member: member}, group, user) do
    Communities.transfer_group_ownership(group, member.user_id, actor: user)
  end

  defp refresh_after_membership_change(socket) do
    user = socket.assigns.current_user
    group = socket.assigns.group

    case load_group(group.slug, user) do
      {:ok, reloaded_group} ->
        socket
        |> assign(:group, reloaded_group)
        |> refresh_members_if_visible(reloaded_group, user)

      :error ->
        socket
        |> put_flash(:error, "Your organizer access to #{group.name} has changed.")
        |> push_navigate(to: ~p"/organize")
    end
  end

  defp refresh_members_if_visible(%{assigns: %{live_action: :members}} = socket, group, user) do
    assign(socket, :members, list_group_members(group, user))
  end

  defp refresh_members_if_visible(socket, _group, _user), do: socket

  defp member_action_allowed?(:promote, %{role: :member} = member, _group, user) do
    Ash.can?({member, :change_role, %{role: :organizer}}, user)
  end

  defp member_action_allowed?(:demote, %{role: :organizer} = member, _group, user) do
    Ash.can?({member, :change_role, %{role: :member}}, user)
  end

  defp member_action_allowed?(:remove, %{role: role} = member, group, user)
       when role in [:member, :organizer] do
    Ash.can?(
      {member, :remove_member, %{group_id: group.id, user_id: member.user_id}},
      user
    )
  end

  defp member_action_allowed?(:transfer, %{role: role} = member, group, user)
       when role in [:member, :organizer] do
    Ash.can?({group, :transfer_ownership, %{new_owner_id: member.user_id}}, user)
  end

  defp member_action_allowed?(_action, _member, _group, _user), do: false

  defp parse_member_action("promote"), do: {:ok, :promote}
  defp parse_member_action("demote"), do: {:ok, :demote}
  defp parse_member_action("remove"), do: {:ok, :remove}
  defp parse_member_action("transfer"), do: {:ok, :transfer}
  defp parse_member_action(_action), do: :error

  defp confirmation_valid?(:transfer, socket) do
    socket.assigns.ownership_confirmation == to_string(socket.assigns.group.name)
  end

  defp confirmation_valid?(_action, _socket), do: true

  defp member_action_title(%{type: :promote, member: member}),
    do: "Promote #{member_name(member)}?"

  defp member_action_title(%{type: :demote, member: member}),
    do: "Demote #{member_name(member)}?"

  defp member_action_title(%{type: :remove, member: member}),
    do: "Remove #{member_name(member)}?"

  defp member_action_title(%{type: :transfer, member: member}),
    do: "Transfer ownership to #{member_name(member)}?"

  defp member_action_description(%{type: :promote}, group),
    do: "This person will be able to organize #{group.name} and manage regular members."

  defp member_action_description(%{type: :demote}, group),
    do: "This person will immediately lose organizer access to #{group.name}."

  defp member_action_description(%{type: :remove}, group),
    do:
      "This person will lose access to private #{group.name} content. Their existing RSVP records are preserved."

  defp member_action_description(%{type: :transfer}, group),
    do:
      "You will become an organizer. The new owner will control #{group.name}, including roles and ownership."

  defp member_action_confirm_label(:promote), do: "Promote to organizer"
  defp member_action_confirm_label(:demote), do: "Demote to member"
  defp member_action_confirm_label(:remove), do: "Remove from group"
  defp member_action_confirm_label(:transfer), do: "Transfer ownership"

  defp member_action_button_variant(:promote), do: :primary
  defp member_action_button_variant(_action), do: :destructive

  defp member_action_success(%{type: :promote, member: member}),
    do: "#{member_name(member)} is now an organizer."

  defp member_action_success(%{type: :demote, member: member}),
    do: "#{member_name(member)} is now a member."

  defp member_action_success(%{type: :remove, member: member}),
    do: "#{member_name(member)} was removed from the group."

  defp member_action_success(%{type: :transfer, member: member}),
    do: "Ownership transferred to #{member_name(member)}."

  defp role_heading(:owner), do: "Owner"
  defp role_heading(:organizer), do: "Organizers"
  defp role_heading(:member), do: "Members"

  defp role_label(:owner), do: "Owner"
  defp role_label(:organizer), do: "Organizer"
  defp role_label(:member), do: "Member"

  defp role_pill_class(:owner), do: "cyan"
  defp role_pill_class(:organizer), do: "warn"
  defp role_pill_class(_), do: nil

  defp role_empty_copy(:organizer),
    do: "No organizers yet. Promote a member to organizer to share the load."

  defp role_empty_copy(:member), do: "Nobody has joined yet."
  defp role_empty_copy(_), do: ""

  defp member_count_heading(1), do: "1 person in this group"
  defp member_count_heading(n), do: "#{n} people in this group"

  defp member_name(%{user: %{display_name: name}}) when is_binary(name) and name != "", do: name
  defp member_name(%{user: %{email: email}}) when is_binary(email), do: email
  defp member_name(_), do: "Unknown member"

  defp format_member_meta(%{created_at: %DateTime{} = at}),
    do: "Joined " <> format_date_short(at)

  defp format_member_meta(_), do: ""

  defp format_date_short(%DateTime{} = at), do: Calendar.strftime(at, "%b %d, %Y")

  defp format_starts_at(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y · %I:%M %p")
  defp format_starts_at(_), do: ""

  defp visibility_label(true), do: "Public"
  defp visibility_label(false), do: "Private"

  defp visibility_subtitle(true), do: "Anyone can find it"
  defp visibility_subtitle(false), do: "Invite only"

  defp member_label(0), do: "No members yet"
  defp member_label(1), do: "1 member"
  defp member_label(n), do: "#{n} members"

  defp group_count_label(1), do: "1 group"
  defp group_count_label(n), do: "#{n} groups"

  defp rsvp_label(0), do: "0 RSVPs"
  defp rsvp_label(1), do: "1 RSVP"
  defp rsvp_label(n), do: "#{n} RSVPs"
end
