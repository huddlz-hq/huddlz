defmodule HuddlzWeb.GroupLive.Show do
  @moduledoc """
  LiveView for displaying a group's details, members, and huddlz.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.HuddlCardHelpers

  alias Huddlz.Communities
  alias Huddlz.Communities.{GroupLocation, GroupMember, Huddl, MembershipEvents}
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Avatar
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.MetaHelpers
  alias Phoenix.LiveView.JS

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @member_grid_visible 7

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:leave_dialog_open, false)
     |> assign(:subscribed_group_id, nil)
     |> assign(:members_visible?, false)
     |> assign(:member_grid_extras, 0)
     |> assign(:huddl_count, 0)
     |> stream(:member_grid, [])
     |> stream(:huddlz, [])}
  end

  @impl true
  def handle_params(%{"slug" => slug} = params, _, socket) do
    user = socket.assigns.current_user

    case get_group_by_slug(slug, user) do
      {:ok, group} ->
        tab = if params["tab"] == "past", do: "past", else: "upcoming"
        page = if tab == "past", do: parse_page(params["page"]), else: 1

        meta =
          Map.put(
            group_meta(group),
            :url,
            unverified_url(HuddlzWeb.Endpoint, group_page_path(group, tab, page))
          )

        membership = current_user_membership(group, user)
        members = get_members(group, user, !is_nil(membership))

        socket =
          socket
          |> subscribe_to_membership_changes(group)
          |> assign(:page_title, group.name)
          |> assign(:meta, meta)
          |> assign(:canonical_url, if(group.is_public, do: meta.url))
          |> assign(:group, group)
          |> assign_member_grid(members)
          |> assign(:member_count, group.member_count)
          |> assign(:is_member, !is_nil(membership))
          |> assign_action_permissions(group, user, membership)
          |> assign(:active_tab, tab)
          |> assign(:past_page, page)
          |> assign(:past_total_pages, 1)
          |> refresh_huddlz()

        if tab == "past" and page > socket.assigns.past_total_pages do
          {:noreply,
           push_patch(socket, to: group_page_path(group, tab, socket.assigns.past_total_pages))}
        else
          {:noreply, socket}
        end

      {:error, _reason} ->
        not_found!()
    end
  end

  @impl true
  def handle_info(
        {:group_membership_changed, group_id},
        %{assigns: %{group: %{id: group_id}}} = socket
      ) do
    {:noreply, refresh_membership_state(socket)}
  end

  def handle_info({:group_membership_changed, _group_id}, socket), do: {:noreply, socket}

  defp subscribe_to_membership_changes(socket, group) do
    if connected?(socket) and socket.assigns.subscribed_group_id != group.id do
      :ok = MembershipEvents.subscribe(group.id)
      assign(socket, :subscribed_group_id, group.id)
    else
      socket
    end
  end

  defp refresh_membership_state(socket) do
    user = socket.assigns.current_user

    case get_group_by_slug(socket.assigns.group.slug, user) do
      {:ok, group} ->
        membership = current_user_membership(group, user)

        socket
        |> assign(:group, group)
        |> assign_member_grid(get_members(group, user, !is_nil(membership)))
        |> assign(:member_count, group.member_count)
        |> assign(:is_member, !is_nil(membership))
        |> assign_action_permissions(group, user, membership)
        |> refresh_huddlz()
        |> assign(:leave_dialog_open, false)

      {:error, _reason} ->
        handle_error(socket, :not_found,
          resource_name: "Group",
          fallback_path: ~p"/discover?#{[scope: "groups"]}"
        )
    end
  end

  defp assign_action_permissions(socket, group, user, membership) do
    socket
    |> assign(:can_edit_group, Ash.can?({group, :update_details}, user))
    |> assign(
      :can_manage_locations,
      Ash.can?({GroupLocation, :create, %{group_id: group.id}}, user)
    )
    |> assign(:can_create_huddl, Ash.can?({Huddl, :create, %{group_id: group.id}}, user))
    |> assign(
      :can_join_group,
      Ash.can?({GroupMember, :join_group, %{group_id: group.id}}, user)
    )
    |> assign(:can_leave_group, can_leave?(membership, user))
  end

  defp can_leave?(nil, _user), do: false
  # Owners cannot leave their own group — the action validation enforces this even
  # for admins (whose policy bypass otherwise tells Ash.can? "yes"). Short-circuit
  # so the button never renders for an owner row.
  defp can_leave?(%{role: :owner}, _user), do: false
  defp can_leave?(membership, user), do: Ash.can?({membership, :leave_group}, user)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="discover"
    >
      <HuddlzWeb.StructuredData.group group={@group} url={@canonical_url} />
      <div class="huddl-frame">
        <div class="huddl-main">
          <header id="group-detail-hero" class="hero group-hero">
            <div class="hero-media">
              <.group_cover
                id={"group-detail-cover-#{@group.id}"}
                group={@group}
                variant={:hero}
              />
            </div>
            <div class="hero-content">
              <.pill variant={if @group.is_public, do: :cyan, else: :warn}>
                {if @group.is_public, do: "Public group", else: "Private group"}
              </.pill>
              <h1>{@group.name}</h1>
              <div class="meta group-hero-meta">
                <span :if={@group.location} class="meta-item group-hero-location">
                  <.icon name="hero-map-pin" class="size-4" />
                  <span>{@group.location}</span>
                </span>
                <span :if={@member_count && @member_count > 0} class="meta-item">
                  <.icon name="hero-users" class="size-4" />
                  <span>{member_count_label(@member_count)}</span>
                </span>
              </div>
            </div>
          </header>

          <div class="huddl-intro prose">
            <%= if @group.description do %>
              <p :for={paragraph <- description_paragraphs(@group.description)}>{paragraph}</p>
            <% else %>
              <p>No description provided.</p>
            <% end %>
          </div>
        </div>

        <aside class="huddl-side">
          <ul class="facts">
            <li>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path d="M17 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
                <circle cx="9.5" cy="7" r="4" />
              </svg>
              <div>
                <div class="label">Members</div>
                <div class="value">{@member_count}</div>
              </div>
            </li>
            <li :if={@group.location}>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z" />
                <circle cx="12" cy="10" r="3" />
              </svg>
              <div>
                <div class="label">Where</div>
                <div class="value">{@group.location}</div>
              </div>
            </li>
            <li>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <%= if @group.is_public do %>
                  <circle cx="12" cy="12" r="10" />
                  <path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20" />
                <% else %>
                  <rect x="5" y="11" width="14" height="10" rx="2" />
                  <path d="M8 11V7a4 4 0 1 1 8 0v4" />
                <% end %>
              </svg>
              <div>
                <div class="label">Visibility</div>
                <div class="value">
                  <%= if @group.is_public do %>
                    Public
                  <% else %>
                    Private
                  <% end %>
                </div>
              </div>
            </li>
          </ul>

          <%= if @current_user do %>
            <div class="side-actions">
              <div :if={role_pill(assigns)} class="role-pill">
                <.pill variant={:cyan}>{role_pill(assigns)}</.pill>
              </div>
              <.button
                :if={@can_create_huddl}
                variant={:primary}
                class="side-actions-primary"
                navigate={~p"/groups/#{@group.slug}/huddlz/new"}
              >
                <.icon name="hero-plus" class="size-4" /> Create Huddl
              </.button>
              <div :if={@can_edit_group or @can_manage_locations} class="side-actions-row">
                <.button
                  :if={@can_edit_group}
                  variant={:secondary}
                  navigate={~p"/groups/#{@group.slug}/edit"}
                >
                  Edit Group
                </.button>
                <.button
                  :if={@can_manage_locations}
                  variant={:secondary}
                  navigate={~p"/groups/#{@group.slug}/locations"}
                >
                  Locations
                </.button>
              </div>
              <.button
                :if={!@is_member and @can_join_group}
                variant={:primary}
                class="side-actions-primary"
                phx-click="join_group"
                phx-disable-with="Joining..."
              >
                Join Group
              </.button>
              <.button
                :if={@can_leave_group}
                variant={:muted}
                phx-click="open_leave_dialog"
              >
                Leave Group
              </.button>
            </div>
          <% end %>

          <div class="huddl-side-section">
            <h3>Share</h3>
            <.share_actions id="share-group-modal" url={@meta.url} title={@page_title} />
          </div>

          <div class="huddl-side-section">
            <h3>Members</h3>
            <%= if @members_visible? do %>
              <div class="member-grid compact">
                <div id="member-grid" class="contents" phx-update="stream">
                  <div
                    :for={{id, entry} <- @streams.member_grid}
                    id={id}
                    class="member-mini"
                  >
                    <div
                      class={["member-mark", entry.mark_variant]}
                      title={entry.member.display_name || "Member"}
                    >
                      <%= if url = Avatar.picture_url(entry.member) do %>
                        <img src={url} alt={entry.member.display_name || ""} />
                      <% else %>
                        {member_initials(entry.member)}
                      <% end %>
                    </div>
                  </div>
                </div>
                <div :if={@member_grid_extras > 0} class="member-mini">
                  <div class="member-mark m4">+{@member_grid_extras}</div>
                </div>
              </div>
            <% else %>
              <div class="member-grid-empty muted">
                <%= if @current_user do %>
                  Only members can see who's in this group.
                <% else %>
                  Sign in to see who's in this group.
                <% end %>
              </div>
            <% end %>
          </div>
        </aside>

        <section class="huddl-rest group-huddlz" aria-labelledby="group-huddlz-title">
          <div class="list-head">
            <h2 id="group-huddlz-title">Huddlz</h2>
            <nav class="filters" aria-label="Huddl timeframe">
              <.link
                id="group-huddlz-upcoming"
                patch={group_page_path(@group, "upcoming", 1)}
                aria-current={@active_tab == "upcoming" && "page"}
                class={["chip", @active_tab == "upcoming" && "is-active"]}
              >
                Upcoming
              </.link>
              <.link
                id="group-huddlz-past"
                patch={group_page_path(@group, "past", 1)}
                aria-current={@active_tab == "past" && "page"}
                class={["chip", @active_tab == "past" && "is-active"]}
              >
                Past
              </.link>
            </nav>
          </div>

          <.huddl_grid huddlz={@streams.huddlz} />
          <.empty_state
            :if={@huddl_count == 0}
            id="group-huddl-grid-empty"
            icon={if @active_tab == "upcoming", do: "hero-calendar", else: "hero-clock"}
            title={if @active_tab == "upcoming", do: "Nothing scheduled", else: "No past huddlz"}
          >
            {if @active_tab == "upcoming",
              do: "No upcoming huddlz scheduled.",
              else: "No past huddlz found."}
          </.empty_state>
          <.pagination
            :if={@active_tab == "past" && @past_total_pages > 1}
            current_page={@past_page}
            total_pages={@past_total_pages}
            id="group-archive-pagination"
            page_path={&group_page_path(@group, "past", &1)}
          />
        </section>
      </div>

      <.share_modal id="share-group-modal" url={@meta.url} label="group" />

      <.modal
        :if={@leave_dialog_open}
        id="leave-group-dialog"
        show
        on_cancel={JS.push("cancel_leave_group")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-5" />
          </div>

          <div class="delete-confirm-copy">
            <h2 id="leave-group-dialog-title">Leave {@group.name}?</h2>
            <p>Leaving this group will:</p>
            <ul class="leave-confirm-list">
              <li>
                <.icon name="hero-user-group" class="size-4" />
                <span>Remove you from the <strong>member roster</strong></span>
              </li>
              <li>
                <.icon name="hero-rectangle-stack" class="size-4" />
                <span>Remove this group from <strong>My groups</strong></span>
              </li>
              <li>
                <.icon name="hero-bell-slash" class="size-4" />
                <span>Stop <strong>notifications</strong> from this group</span>
              </li>
            </ul>
            <p class="leave-confirm-note">
              Leaving does not cancel your existing RSVPs.
              You can rejoin later if the group is public or you receive another invitation.
            </p>
          </div>
        </div>

        <div class="delete-confirm-actions">
          <.button id="leave-group-dialog-cancel" variant={:muted} phx-click="cancel_leave_group">
            Cancel
          </.button>
          <.button
            variant={:destructive}
            class="delete-confirm-submit"
            phx-click="leave_group"
            phx-disable-with="Leaving..."
          >
            Yes, leave group
          </.button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  attr :huddlz, Phoenix.LiveView.LiveStream, required: true

  defp huddl_grid(assigns) do
    ~H"""
    <div id="group-huddl-grid" class="grid two" phx-update="stream">
      <.card
        :for={{id, %{huddl: huddl}} <- @huddlz}
        id={id}
        navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}
      >
        <:cover>
          <%= if huddl.display_image_url do %>
            <.cover_image
              id={"group-huddl-card-cover-#{huddl.id}"}
              class="card-cover-img"
              image_url={huddl.display_image_url}
            />
          <% else %>
            <.cover_fallback name={huddl.group.name} />
          <% end %>
          <.date_stamp month={huddl_month(huddl)} day={huddl_day(huddl)} />
          <.card_tag variant={tag_variant(huddl.event_type)}>
            {tag_label(huddl.event_type)}
          </.card_tag>
        </:cover>
        <:body>
          <span class="card-group">{huddl_kind_label(huddl)}</span>
          <h3 class="card-title">{huddl.title}</h3>
          <div class="card-meta">
            <span>{format_meta_when(huddl)}</span>
            <%= if huddl.rsvp_count > 0 || huddl.max_attendees do %>
              <span class="dot"></span>
              <span>{rsvp_label(huddl)}</span>
            <% end %>
          </div>
        </:body>
      </.card>
    </div>
    """
  end

  defp stream_huddlz(socket, huddlz) do
    entries = Enum.map(huddlz, &%{id: &1.id, huddl: &1})

    socket
    |> assign(:huddl_count, length(entries))
    |> stream(:huddlz, entries, reset: true)
  end

  defp refresh_huddlz(%{assigns: %{active_tab: "past"}} = socket) do
    {huddlz, total_pages} =
      get_past_group_huddlz_paginated(socket.assigns.group, socket.assigns.current_user,
        page: socket.assigns.past_page,
        per_page: 10
      )

    socket
    |> stream_huddlz(huddlz)
    |> assign(:past_total_pages, total_pages)
  end

  defp refresh_huddlz(socket) do
    stream_huddlz(
      socket,
      get_upcoming_group_huddlz(socket.assigns.group, socket.assigns.current_user, limit: 10)
    )
  end

  defp group_page_path(group, "past", page) when page > 1,
    do: ~p"/groups/#{group.slug}?#{[tab: "past", page: page]}"

  defp group_page_path(group, "past", _page), do: ~p"/groups/#{group.slug}?#{[tab: "past"]}"
  defp group_page_path(group, _tab, _page), do: ~p"/groups/#{group.slug}"

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: group_page_path(socket.assigns.group, tab, 1))}
  end

  def handle_event("change_past_page", %{"page" => page_str}, socket) do
    {:noreply,
     push_patch(socket,
       to: group_page_path(socket.assigns.group, "past", parse_page(page_str))
     )}
  end

  def handle_event("join_group", _, socket) do
    user = socket.assigns.current_user

    case join_group(socket.assigns.group, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the group!")
         |> refresh_membership_state()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end

  def handle_event("open_leave_dialog", _, %{assigns: %{can_leave_group: true}} = socket) do
    {:noreply, assign(socket, :leave_dialog_open, true)}
  end

  def handle_event("open_leave_dialog", _, socket), do: {:noreply, socket}

  def handle_event("cancel_leave_group", _, socket) do
    {:noreply, assign(socket, :leave_dialog_open, false)}
  end

  def handle_event("leave_group", _, %{assigns: %{leave_dialog_open: true}} = socket) do
    user = socket.assigns.current_user

    case leave_group(socket.assigns.group, user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully left the group")
         |> refresh_membership_state()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end

  def handle_event("leave_group", _, socket), do: {:noreply, socket}

  @group_loads [
    :current_image_url,
    :member_count,
    :viewer_role,
    owner: [:current_profile_picture_url]
  ]

  defp get_group_by_slug(slug, actor) do
    case Communities.get_by_slug(slug, actor: actor, load: @group_loads) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp group_meta(group) do
    %{
      title: "#{group.name} · huddlz",
      description: MetaHelpers.description(group, "Find and join this group on huddlz."),
      type: "website",
      url: url(~p"/groups/#{group.slug}"),
      image:
        MetaHelpers.image_url(group.current_image_url, GroupImages) ||
          generated_card_url(group)
    }
  end

  defp generated_card_url(%{is_public: true, slug: slug}),
    do: url(~p"/og/groups/#{slug}/card.png")

  defp generated_card_url(_group), do: nil

  defp current_user_membership(_group, nil), do: nil

  defp current_user_membership(group, user) do
    case Communities.get_membership_in_group(group.id, actor: user) do
      {:ok, membership} -> membership
      _ -> nil
    end
  end

  defp get_members(_group, _user, false), do: nil
  defp get_members(_group, nil, _), do: nil

  defp get_members(group, user, true) do
    group.id
    |> Communities.get_by_group!(actor: user, load: [user: [:current_profile_picture_url]])
    |> Enum.map(& &1.user)
  end

  defp join_group(group, user) do
    GroupMember
    |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, actor: user)
    |> Ash.create()
  end

  defp leave_group(group, user) do
    case Communities.get_membership_in_group(group.id, actor: user) do
      {:ok, %{} = membership} ->
        Ash.destroy(membership, action: :leave_group, actor: user)

      _ ->
        {:error, :not_a_member}
    end
  end

  defp get_upcoming_group_huddlz(group, user, opts) do
    limit = Keyword.get(opts, :limit, 10)

    page =
      Communities.get_group_huddlz!(group.id,
        actor: user,
        page: [limit: limit],
        load: [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]
      )

    page.results
  end

  defp get_past_group_huddlz_paginated(group, user, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page

    page_result =
      Communities.get_past_group_huddlz!(group.id,
        actor: user,
        query: [sort: [starts_at: :desc, id: :desc]],
        page: [limit: per_page, offset: offset, count: true],
        load: [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]
      )

    total_pages =
      if page_result.count && page_result.count > 0 do
        ceil(page_result.count / per_page)
      else
        1
      end

    {page_result.results, total_pages}
  end

  # Mirrors the clamped parser the other pagination LiveViews use, so a
  # crafted non-numeric "page" value over the socket can't crash the process.
  defp parse_page(nil), do: 1
  defp parse_page(""), do: 1

  defp parse_page(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n >= 1 -> n
      _ -> 1
    end
  end

  defp parse_page(val) when is_integer(val) and val >= 1, do: val
  defp parse_page(_), do: 1

  defp role_pill(%{group: group}), do: HuddlzWeb.GroupRole.label(group.viewer_role)

  defp assign_member_grid(socket, nil) do
    socket
    |> assign(:members_visible?, false)
    |> assign(:member_grid_extras, 0)
    |> stream(:member_grid, [], reset: true)
  end

  defp assign_member_grid(socket, members) do
    entries =
      members
      |> Enum.take(@member_grid_visible)
      |> Enum.with_index()
      |> Enum.map(fn {member, index} ->
        %{id: member.id, member: member, mark_variant: member_mark_variant(index)}
      end)

    socket
    |> assign(:members_visible?, true)
    |> assign(:member_grid_extras, max(length(members) - @member_grid_visible, 0))
    |> stream(:member_grid, entries, reset: true)
  end

  defp member_mark_variant(idx), do: "m#{Integer.mod(idx, 5) + 1}"

  defp member_initials(member) do
    case Avatar.initials(member) do
      nil -> "?"
      initials -> initials
    end
  end

  defp member_count_label(1), do: "1 member"
  defp member_count_label(n) when is_integer(n), do: "#{n} members"

  defp description_paragraphs(description) do
    description
    |> to_string()
    |> String.split(~r/\R{2,}/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp huddl_kind_label(%{event_type: type}) when type in [:in_person, :virtual, :hybrid],
    do: tag_label(type)

  defp huddl_kind_label(_), do: "Huddl"
end
