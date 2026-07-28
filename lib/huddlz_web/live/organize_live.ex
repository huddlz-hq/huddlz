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

  alias Huddlz.Accounts
  alias Huddlz.Communities
  alias Huddlz.Communities.MembershipEvents
  alias HuddlzWeb.Layouts

  @group_loads [:member_count]
  @huddl_loads [:rsvp_count, :status, :group]
  @upcoming_loads [:rsvp_count, :group]
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
     |> assign(:invitation_count, 0)
     |> assign(:invitation_form, invitation_form())
     |> assign(:member_lookup, %{})
     |> assign(:member_role_counts, %{owner: 0, organizer: 0, member: 0})
     |> assign(:subscribed_group_id, nil)
     |> assign(:pending_member_action, nil)
     |> assign(:member_action_form, member_action_form())
     |> assign(:transfer_target_form, transfer_target_form())
     |> assign(:transfer_candidates, [])
     |> stream(:invitations, [])
     |> stream(:owner_members, [])
     |> stream(:organizer_members, [])
     |> stream(:regular_members, [])}
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

  defp load_action(socket, :index, _params, _user) do
    socket
    |> assign(:group, nil)
    |> assign(:owned_groups, socket.assigns.sidebar_owned_groups)
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
    invitations = list_group_invitations(group, user)

    socket
    |> assign_members(members)
    |> assign(:invitation_count, length(invitations))
    |> stream(:invitations, invitations, reset: true)
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

  defp list_group_invitations(group, user) do
    group.id
    |> Communities.list_group_invitations!(
      actor: user,
      load: [:invitee, :inviter]
    )
    |> Enum.map(&normalize_invitation_expiration(&1, user))
  end

  defp create_invitation(socket, group, user, invitee, role, email, params) do
    case Communities.invite_to_group(group.id, invitee.id, role, actor: user) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}.")
         |> assign(:invitation_form, invitation_form())
         |> refresh_invitations(group, user)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Could not send that invitation. They may already be a member or have a pending invitation."
         )
         |> assign(:invitation_form, invitation_form(params))}
    end
  end

  defp refresh_invitations(socket, group, user) do
    invitations = list_group_invitations(group, user)

    socket
    |> assign(:invitation_count, length(invitations))
    |> stream(:invitations, invitations, reset: true)
  end

  defp invitation_form(params \\ %{"email" => "", "role" => "member"}) do
    to_form(params, as: :invitation)
  end

  defp parse_invitation_role("organizer"), do: :organizer
  defp parse_invitation_role(_), do: :member

  defp normalize_invitation_expiration(
         %{status: :pending, expires_at: expires_at} = invitation,
         user
       ) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      invitation
    else
      invitation
      |> Communities.expire_group_invitation!(actor: user)
      |> Communities.load_group_invitation_details!()
    end
  end

  defp normalize_invitation_expiration(invitation, _user), do: invitation

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
      unread_notification_count={@unread_notification_count}
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
          <.members_view
            group={@group}
            owner_members={@streams.owner_members}
            organizer_members={@streams.organizer_members}
            regular_members={@streams.regular_members}
            role_counts={@member_role_counts}
            transfer_candidates={@transfer_candidates}
            transfer_target_form={@transfer_target_form}
            current_user={@current_user}
          />
          <.invitations_view
            :if={!@group.is_public}
            group={@group}
            current_user={@current_user}
            invitation_form={@invitation_form}
            invitations={@streams.invitations}
            invitation_count={@invitation_count}
          />
      <% end %>

      <.member_action_dialog
        :if={@pending_member_action}
        action={@pending_member_action}
        group={@group}
        form={@member_action_form}
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
  attr :owner_members, :any, required: true
  attr :organizer_members, :any, required: true
  attr :regular_members, :any, required: true
  attr :role_counts, :map, required: true
  attr :transfer_candidates, :list, required: true
  attr :transfer_target_form, Phoenix.HTML.Form, required: true
  attr :current_user, :map, required: true

  defp members_view(assigns) do
    grouped = [
      {:owner, assigns.owner_members, assigns.role_counts.owner},
      {:organizer, assigns.organizer_members, assigns.role_counts.organizer},
      {:member, assigns.regular_members, assigns.role_counts.member}
    ]

    assigns =
      assigns
      |> assign(:grouped, grouped)
      |> assign(
        :can_transfer_ownership,
        assigns.group.owner_id == assigns.current_user.id and assigns.transfer_candidates != []
      )
      |> assign(
        :transfer_candidate_options,
        Enum.map(assigns.transfer_candidates, &{member_name(&1), &1.id})
      )

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

      <%= for {role, rows, count} <- @grouped do %>
        <div class="role-section">
          <div class="role-section-head">
            <h3>{role_heading(role)}</h3>
            <span :if={role != :owner} class="muted count">({count})</span>
          </div>
          <div id={"#{role}-member-rows"} class="row-list" phx-update="stream">
            <p
              id={"#{role}-member-rows-empty"}
              class="hidden only:block muted role-section-empty"
            >
              {role_empty_copy(role)}
            </p>
            <div :for={{id, entry} <- rows} id={id} class="row row-split gap-4">
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
        </div>
      <% end %>
    </div>

    <section
      :if={@can_transfer_ownership}
      id="ownership-danger-zone"
      class="panel mt-6 border-error/40"
      aria-labelledby="ownership-danger-zone-title"
    >
      <div class="panel-head">
        <div>
          <h2 id="ownership-danger-zone-title">Ownership</h2>
          <p class="panel-sub">
            Transfer final control of this group. You will remain an organizer.
          </p>
        </div>
      </div>

      <.form
        for={@transfer_target_form}
        id="transfer-ownership-target-form"
        phx-submit="open_transfer_action"
        class="mt-5 grid gap-4 md:grid-cols-[minmax(0,1fr)_auto] md:items-end"
      >
        <.select
          field={@transfer_target_form[:member_id]}
          id="ownership-recipient"
          label="New owner"
          prompt="Choose an existing member"
          options={@transfer_candidate_options}
        />
        <.button
          id="open-transfer-ownership"
          type="submit"
          variant={:destructive}
          class="md:mb-px"
        >
          Transfer group ownership
        </.button>
      </.form>
    </section>
    """
  end

  attr :group, :map, required: true
  attr :current_user, :map, required: true
  attr :invitation_form, :map, required: true
  attr :invitations, :any, required: true
  attr :invitation_count, :integer, required: true

  defp invitations_view(assigns) do
    ~H"""
    <div id="group-invitations" class="panel mt-6">
      <div class="panel-head">
        <div>
          <h2>Invite someone</h2>
          <div class="panel-sub">Invitations expire after 7 days.</div>
        </div>
      </div>

      <.form
        for={@invitation_form}
        id="group-invitation-form"
        phx-submit="invite"
        class="grid gap-4 md:grid-cols-[minmax(0,1fr)_12rem_auto] md:items-end"
      >
        <.input
          field={@invitation_form[:email]}
          type="email"
          label="Registered email"
          placeholder="person@example.com"
        />
        <.select
          field={@invitation_form[:role]}
          label="Group role"
          options={invitation_role_options(@group, @current_user)}
        />
        <button id="send-group-invitation" type="submit" class="btn-primary">
          Send invitation
        </button>
      </.form>

      <div class="role-section">
        <div class="role-section-head">
          <h3>Invitation history</h3>
          <span class="muted count">({@invitation_count})</span>
        </div>
        <div id="invitation-rows" phx-update="stream" class="row-list">
          <p id="invitations-empty" class="hidden only:block muted role-section-empty">
            No invitations yet.
          </p>
          <div :for={{id, invitation} <- @invitations} id={id} class="row row-split">
            <div>
              <div class="row-title">{member_name(%{user: invitation.invitee})}</div>
              <div class="meta">
                {role_label(invitation.role)} · {invitation_status_label(invitation.status)}
              </div>
            </div>
            <button
              :if={invitation.status == :pending}
              id={"revoke-invitation-#{invitation.id}"}
              type="button"
              class="pill"
              phx-click="revoke_invitation"
              phx-value-id={invitation.id}
            >
              Revoke
            </button>
            <span :if={invitation.status != :pending} class="pill">
              {invitation_status_label(invitation.status)}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp invitation_role_options(group, user) when group.owner_id == user.id,
    do: [{"Member", "member"}, {"Organizer", "organizer"}]

  defp invitation_role_options(_group, _user), do: [{"Member", "member"}]

  defp invitation_status_label(:pending), do: "Awaiting response"
  defp invitation_status_label(:accepted), do: "Accepted"
  defp invitation_status_label(:declined), do: "Declined"
  defp invitation_status_label(:revoked), do: "Revoked"
  defp invitation_status_label(:expired), do: "Expired"

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
          member_action_allowed?(:remove, assigns.entry, assigns.group, assigns.current_user)
      )

    ~H"""
    <div
      :if={@can_promote or @can_demote or @can_remove}
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
  attr :form, Phoenix.HTML.Form, required: true

  defp member_action_dialog(assigns) do
    assigns = assign(assigns, :ownership_confirmation, assigns.form[:confirmation].value || "")

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

      <.form
        for={@form}
        id="member-action-form"
        phx-submit="confirm_member_action"
        phx-change="validate_member_action_confirmation"
        class="mt-6"
      >
        <.input
          :if={@action.type == :transfer}
          field={@form[:confirmation]}
          id="ownership-confirmation"
          label={"Type #{@group.name} to confirm"}
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
      </.form>
    </.modal>
    """
  end

  @impl true
  def handle_event("invite", %{"invitation" => params}, socket) do
    group = socket.assigns.group
    user = socket.assigns.current_user
    email = String.trim(params["email"] || "")
    role = parse_invitation_role(params["role"])

    case Accounts.get_by_email(email, actor: user) do
      {:ok, invitee} ->
        create_invitation(socket, group, user, invitee, role, email, params)

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "No registered person has that email address.")
         |> assign(:invitation_form, invitation_form(params))}
    end
  end

  def handle_event("revoke_invitation", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    group = socket.assigns.group
    group_id = group.id

    with {:ok, invitation} <-
           Communities.get_group_invitation(id, actor: user),
         %{group_id: ^group_id} <- invitation,
         {:ok, _revoked} <- Communities.revoke_group_invitation(invitation, actor: user) do
      {:noreply,
       socket
       |> put_flash(:info, "Invitation revoked.")
       |> refresh_invitations(group, user)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "That invitation could not be revoked.")}
    end
  end

  def handle_event("open_member_action", %{"id" => id, "action" => action}, socket) do
    case parse_member_action(action) do
      {:ok, action_type} ->
        open_member_action(socket, id, action_type)

      _ ->
        {:noreply, put_flash(socket, :error, "That membership action is not available.")}
    end
  end

  def handle_event(
        "open_transfer_action",
        %{"transfer_target" => %{"member_id" => id}},
        socket
      ) do
    open_member_action(socket, id, :transfer)
  end

  def handle_event("open_transfer_action", _params, socket) do
    {:noreply, put_flash(socket, :error, "Choose a member to receive ownership.")}
  end

  def handle_event("cancel_member_action", _params, socket) do
    {:noreply,
     socket
     |> assign(:pending_member_action, nil)
     |> assign(:member_action_form, member_action_form())}
  end

  def handle_event(
        "validate_member_action_confirmation",
        %{"member_action" => params},
        socket
      ) do
    {:noreply, assign(socket, :member_action_form, member_action_form(params))}
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

  defp open_member_action(socket, id, action_type) do
    with %{} = member <- Map.get(socket.assigns.member_lookup, id),
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
       |> assign(:member_action_form, member_action_form())}
    else
      _ -> {:noreply, put_flash(socket, :error, "That membership action is not available.")}
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
         |> assign(:member_action_form, member_action_form())
         |> put_flash(:info, member_action_success(action))
         |> refresh_after_membership_change()}

      :ok ->
        {:noreply,
         socket
         |> assign(:pending_member_action, nil)
         |> assign(:member_action_form, member_action_form())
         |> put_flash(:info, member_action_success(action))
         |> refresh_after_membership_change()}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:pending_member_action, nil)
         |> assign(:member_action_form, member_action_form())
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
    assign_members(socket, list_group_members(group, user))
  end

  defp refresh_members_if_visible(socket, _group, _user), do: socket

  defp assign_members(socket, members) do
    by_role = Enum.group_by(members, & &1.role)

    socket
    |> assign(:member_lookup, Map.new(members, &{&1.id, &1}))
    |> assign(:transfer_candidates, Enum.reject(members, &(&1.role == :owner)))
    |> assign(:transfer_target_form, transfer_target_form())
    |> assign(:member_role_counts, %{
      owner: length(Map.get(by_role, :owner, [])),
      organizer: length(Map.get(by_role, :organizer, [])),
      member: length(Map.get(by_role, :member, []))
    })
    |> stream(:owner_members, Map.get(by_role, :owner, []), reset: true)
    |> stream(:organizer_members, Map.get(by_role, :organizer, []), reset: true)
    |> stream(:regular_members, Map.get(by_role, :member, []), reset: true)
  end

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
    socket.assigns.member_action_form[:confirmation].value ==
      to_string(socket.assigns.group.name)
  end

  defp confirmation_valid?(_action, _socket), do: true

  defp member_action_form(params \\ %{}) do
    params
    |> Map.put_new("confirmation", "")
    |> to_form(as: :member_action)
  end

  defp transfer_target_form(params \\ %{}) do
    params
    |> Map.put_new("member_id", "")
    |> to_form(as: :transfer_target)
  end

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
