defmodule HuddlzWeb.GroupLive.Show do
  @moduledoc """
  LiveView for displaying a group's details, members, and huddlz.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.{GroupLocation, GroupMember, Huddl}
  alias Huddlz.Storage.GroupImages
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Avatar
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.MetaHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

  @member_grid_visible 7

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    user = socket.assigns.current_user

    case get_group_by_slug(slug, user) do
      {:ok, group} ->
        membership = current_user_membership(group, user)
        members = get_members(group, user, !is_nil(membership))
        upcoming_huddlz = get_upcoming_group_huddlz(group, user, limit: 10)

        {:noreply,
         socket
         |> assign(:page_title, group.name)
         |> assign(:meta, group_meta(group))
         |> assign(:group, group)
         |> assign(:members, members)
         |> assign(:member_count, group.member_count)
         |> assign(:is_member, !is_nil(membership))
         |> assign_action_permissions(group, user, membership)
         |> assign(:active_tab, "upcoming")
         |> assign(:upcoming_huddlz, upcoming_huddlz)
         |> assign(:past_huddlz, [])
         |> assign(:past_page, 1)
         |> assign(:past_total_pages, 0)}

      {:error, _reason} ->
        {:noreply,
         handle_error(socket, :not_found,
           resource_name: "Group",
           fallback_path: ~p"/discover?#{[scope: "groups"]}"
         )}
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
    <Layouts.v3_app flash={@flash} current_user={@current_user} active="discover">
      <div class="hero">
        <img
          :if={@group.current_image_url}
          class="hero-img"
          src={GroupImages.url(@group.current_image_url)}
          alt={@group.name}
        />
        <div class="hero-content">
          <span class="eyebrow">
            Group ·
            <%= if @group.is_public do %>
              Public
            <% else %>
              <span class="eyebrow-warn">Private</span>
            <% end %>
          </span>
          <h1>{@group.name}</h1>
          <div class="meta">
            <span :if={@group.location}>📍 {@group.location}</span>
            <span :if={@group.location && @member_count && @member_count > 0}>·</span>
            <span :if={@member_count && @member_count > 0}>
              {member_count_label(@member_count)}
            </span>
          </div>
        </div>
      </div>

      <div class="huddl-frame">
        <div class="huddl-intro prose">
          <%= if @group.description do %>
            <p :for={paragraph <- description_paragraphs(@group.description)}>{paragraph}</p>
          <% else %>
            <p>No description provided.</p>
          <% end %>
        </div>

        <aside class="huddl-side">
          <h3>This group</h3>
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
            <div :if={role_pill(assigns)} class="role-pill">
              <.v3_pill variant={:cyan}>{role_pill(assigns)}</.v3_pill>
            </div>
            <div class="side-actions">
              <.v3_button
                :if={@can_create_huddl}
                variant={:primary}
                navigate={~p"/groups/#{@group.slug}/huddlz/new"}
              >
                + Create Huddl
              </.v3_button>
              <.v3_button
                :if={@can_edit_group}
                variant={:secondary}
                navigate={~p"/groups/#{@group.slug}/edit"}
              >
                Edit Group
              </.v3_button>
              <.v3_button
                :if={@can_manage_locations}
                variant={:secondary}
                navigate={~p"/groups/#{@group.slug}/locations"}
              >
                Locations
              </.v3_button>
              <.v3_button
                :if={!@is_member and @can_join_group}
                variant={:primary}
                phx-click="join_group"
              >
                Join Group
              </.v3_button>
              <.v3_button
                :if={@can_leave_group}
                variant={:muted}
                phx-click="leave_group"
                data-confirm="Are you sure you want to leave this group?"
              >
                Leave Group
              </.v3_button>
            </div>
          <% end %>

          <div class="huddl-side-section">
            <h3>Members</h3>
            <%= if @members do %>
              <% {visible, extras} = split_members(@members) %>
              <div class="member-grid compact">
                <div :for={{member, idx} <- Enum.with_index(visible)} class="member-mini">
                  <div
                    class={["member-mark", member_mark_variant(idx)]}
                    title={member.display_name || "Member"}
                  >
                    {member_initials(member)}
                  </div>
                </div>
                <div :if={extras > 0} class="member-mini">
                  <div class="member-mark m4">+{extras}</div>
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

        <div class="huddl-rest">
          <div class="prose">
            <h2>Huddlz</h2>
          </div>

          <div class="filters" role="tablist" aria-label="Huddl timeframe">
            <button
              type="button"
              role="tab"
              aria-selected={@active_tab == "upcoming"}
              class={["chip", @active_tab == "upcoming" && "is-active"]}
              phx-click="switch_tab"
              phx-value-tab="upcoming"
            >
              Upcoming
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={@active_tab == "past"}
              class={["chip", @active_tab == "past" && "is-active"]}
              phx-click="switch_tab"
              phx-value-tab="past"
            >
              Past
            </button>
          </div>

          <%= if @active_tab == "upcoming" do %>
            <.huddl_grid huddlz={@upcoming_huddlz} empty_message="No upcoming huddlz scheduled." />
          <% else %>
            <.huddl_grid huddlz={@past_huddlz} empty_message="No past huddlz found." />
            <.v3_pagination
              :if={@past_total_pages > 1}
              current_page={@past_page}
              total_pages={@past_total_pages}
              event_name="change_past_page"
            />
          <% end %>
        </div>
      </div>
    </Layouts.v3_app>
    """
  end

  attr :huddlz, :list, required: true
  attr :empty_message, :string, required: true

  defp huddl_grid(assigns) do
    ~H"""
    <%= if @huddlz == [] do %>
      <p class="empty-state muted">
        {@empty_message}
      </p>
    <% else %>
      <div class="grid two">
        <.v3_card
          :for={{huddl, idx} <- Enum.with_index(@huddlz)}
          navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}
          gradient={Integer.mod(idx, 6) + 1}
        >
          <:cover>
            <img
              :if={huddl.display_image_url}
              class="card-cover-img"
              src={HuddlImages.url(huddl.display_image_url)}
              alt={huddl.title}
            />
            <.v3_date_stamp month={huddl_month(huddl)} day={huddl_day(huddl)} />
            <.v3_card_tag variant={tag_variant(huddl.event_type)}>
              {tag_label(huddl.event_type)}
            </.v3_card_tag>
          </:cover>
          <:body>
            <span class="card-group">{huddl_kind_label(huddl)}</span>
            <h3 class="card-title">{huddl.title}</h3>
            <div class="card-meta">
              <span>{format_meta_when(huddl.starts_at)}</span>
              <%= if huddl.rsvp_count > 0 || huddl.max_attendees do %>
                <span class="dot"></span>
                <span>{rsvp_label(huddl)}</span>
              <% end %>
            </div>
          </:body>
        </.v3_card>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket =
      case tab do
        "upcoming" ->
          socket
          |> assign(:active_tab, "upcoming")

        "past" ->
          {past_huddlz, total_pages} =
            get_past_group_huddlz_paginated(
              socket.assigns.group,
              socket.assigns.current_user,
              page: 1,
              per_page: 10
            )

          socket
          |> assign(:active_tab, "past")
          |> assign(:past_huddlz, past_huddlz)
          |> assign(:past_page, 1)
          |> assign(:past_total_pages, total_pages)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("change_past_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)

    {past_huddlz, total_pages} =
      get_past_group_huddlz_paginated(
        socket.assigns.group,
        socket.assigns.current_user,
        page: page,
        per_page: 10
      )

    socket =
      socket
      |> assign(:past_huddlz, past_huddlz)
      |> assign(:past_page, page)
      |> assign(:past_total_pages, total_pages)

    {:noreply, socket}
  end

  def handle_event("join_group", _, socket) do
    user = socket.assigns.current_user

    case join_group(socket.assigns.group, user) do
      {:ok, _} ->
        group = reload_group(socket.assigns.group, user)
        membership = current_user_membership(group, user)
        members = get_members(group, user, true)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the group!")
         |> assign(:group, group)
         |> assign(:is_member, true)
         |> assign(:members, members)
         |> assign(:member_count, group.member_count)
         |> assign_action_permissions(group, user, membership)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end

  def handle_event("leave_group", _, socket) do
    user = socket.assigns.current_user

    case leave_group(socket.assigns.group, user) do
      {:ok, _} ->
        group = reload_group(socket.assigns.group, user)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully left the group")
         |> assign(:group, group)
         |> assign(:is_member, false)
         |> assign(:members, nil)
         |> assign(:member_count, group.member_count)
         |> assign_action_permissions(group, user, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end

  @group_loads [:current_image_url, :member_count, owner: [:current_profile_picture_url]]

  defp get_group_by_slug(slug, actor) do
    case Communities.get_by_slug(slug, actor: actor, load: @group_loads) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp reload_group(%{slug: slug}, actor) do
    Communities.get_by_slug!(slug, actor: actor, load: @group_loads)
  end

  defp group_meta(group) do
    %{
      title: "#{group.name} · huddlz",
      description: MetaHelpers.description(group, "Find and join this group on huddlz."),
      type: "website",
      url: url(~p"/groups/#{group.slug}"),
      image: MetaHelpers.image_url(group.current_image_url, GroupImages)
    }
  end

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

  defp role_pill(%{can_edit_group: true}), do: "Owner"
  defp role_pill(%{is_member: true}), do: "Joined"
  defp role_pill(_assigns), do: nil

  defp split_members(members) do
    visible = Enum.take(members, @member_grid_visible)
    extras = max(length(members) - @member_grid_visible, 0)
    {visible, extras}
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

  defp tag_variant(:in_person), do: :in_person
  defp tag_variant(:virtual), do: :online
  defp tag_variant(:hybrid), do: :hybrid

  defp tag_label(:in_person), do: "In person"
  defp tag_label(:virtual), do: "Online"
  defp tag_label(:hybrid), do: "Hybrid"

  defp huddl_kind_label(%{event_type: :in_person}), do: "In person"
  defp huddl_kind_label(%{event_type: :virtual}), do: "Online"
  defp huddl_kind_label(%{event_type: :hybrid}), do: "Hybrid"
  defp huddl_kind_label(_), do: "Huddl"

  defp huddl_month(%{starts_at: %DateTime{} = dt}),
    do: Calendar.strftime(dt, "%b") |> String.upcase()

  defp huddl_day(%{starts_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%-d")

  defp format_meta_when(%DateTime{} = dt) do
    "#{Calendar.strftime(dt, "%a")} · #{Calendar.strftime(dt, "%-I:%M %p")}"
  end

  defp rsvp_label(%{rsvp_count: count, max_attendees: max}) when is_integer(max) and max > 0,
    do: "#{count} / #{max} RSVPs"

  defp rsvp_label(%{rsvp_count: 1}), do: "1 RSVP"
  defp rsvp_label(%{rsvp_count: count}), do: "#{count} RSVPs"
end
