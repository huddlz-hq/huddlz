defmodule HuddlzWeb.GroupLive.Show do
  @moduledoc """
  LiveView for displaying a group's details, members, and huddlz.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.GroupMember
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    # Ash policies handle read authorization - not_found covers both missing and unauthorized
    case get_group_by_slug(slug, socket.assigns.current_user) do
      {:ok, group} ->
        members = get_members(group, socket.assigns.current_user)

        # Load upcoming events (limited to 10)
        upcoming_huddlz = get_upcoming_group_huddlz(group, socket.assigns.current_user, limit: 10)

        {:noreply,
         socket
         |> assign(:page_title, group.name)
         |> assign(:group, group)
         |> assign(:members, members)
         |> assign(:member_count, get_member_count(group))
         |> assign(:is_member, member?(group, socket.assigns.current_user))
         |> assign(:is_owner, owner?(group, socket.assigns.current_user))
         |> assign(:is_organizer, organizer?(group, socket.assigns.current_user))
         |> assign(:active_tab, "upcoming")
         |> assign(:upcoming_huddlz, upcoming_huddlz)
         |> assign(:past_huddlz, [])
         |> assign(:past_page, 1)
         |> assign(:past_total_pages, 0)}

      {:error, _reason} ->
        {:noreply,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@group.name}
        <:subtitle>
          <%= if !@group.is_public do %>
            <span class="text-xs px-2.5 py-1 bg-base-300 text-base-content/50 font-medium">
              Private
            </span>
          <% end %>
          <%= if @is_owner do %>
            <span class="text-xs px-2.5 py-1 bg-primary/10 text-primary font-medium">
              Owner
            </span>
          <% end %>
        </:subtitle>
        <:actions>
          <%= if @current_user do %>
            <%= if @is_owner do %>
              <.link
                navigate={~p"/groups/#{@group.slug}/edit"}
                class="inline-flex items-center gap-1.5 text-sm font-medium text-base-content/50 hover:text-base-content transition-colors"
              >
                <.icon name="hero-pencil" class="h-4 w-4" /> Edit Group
              </.link>
            <% end %>

            <%= if @is_owner || @is_organizer do %>
              <.link
                navigate={~p"/groups/#{@group.slug}/huddlz/new"}
                class="inline-flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-content text-sm font-medium btn-neon"
              >
                <.icon name="hero-plus" class="h-4 w-4" /> Create Huddl
              </.link>
            <% end %>

            <%= if !@is_owner do %>
              <%= if @is_member do %>
                <.button
                  phx-click="leave_group"
                  data-confirm="Are you sure you want to leave this group?"
                >
                  Leave Group
                </.button>
              <% else %>
                <%= if @group.is_public do %>
                  <.button phx-click="join_group">
                    Join Group
                  </.button>
                <% end %>
              <% end %>
            <% end %>
          <% end %>
        </:actions>
      </.header>

      <div class="mt-8">
        <div class="mb-6">
          <%= if @group.current_image_url do %>
            <img
              src={GroupImages.url(@group.current_image_url)}
              alt={@group.name}
              class="w-full aspect-video object-cover overflow-hidden"
            />
          <% else %>
            <div class="w-full aspect-video bg-base-100 overflow-hidden flex items-center justify-center">
              <span class="text-4xl font-bold text-base-content/40 text-center px-8 line-clamp-2">
                {@group.name}
              </span>
            </div>
          <% end %>
        </div>

        <div>
          <p class="text-base-content/60">
            {@group.description || "No description provided."}
          </p>

          <%= if @group.location do %>
            <p class="flex items-center gap-2 text-base-content/50 mt-2">
              <.icon name="hero-map-pin" class="h-4 w-4" />
              {@group.location}
            </p>
          <% end %>

          <div class="mt-8">
            <h3 class="font-display text-lg tracking-tight text-glow">Huddlz</h3>

            <div class="flex gap-4 mt-4">
              <button
                class={[
                  "text-sm font-medium transition-colors pb-1",
                  if(@active_tab == "upcoming",
                    do: "text-primary border-b border-primary",
                    else: "text-base-content/40 hover:text-base-content"
                  )
                ]}
                phx-click="switch_tab"
                phx-value-tab="upcoming"
              >
                Upcoming
              </button>
              <button
                class={[
                  "text-sm font-medium transition-colors pb-1",
                  if(@active_tab == "past",
                    do: "text-primary border-b border-primary",
                    else: "text-base-content/40 hover:text-base-content"
                  )
                ]}
                phx-click="switch_tab"
                phx-value-tab="past"
              >
                Past
              </button>
            </div>

            <div class="mt-6">
              <%= if @active_tab == "upcoming" do %>
                <.huddl_list huddlz={@upcoming_huddlz} empty_message="No upcoming huddlz scheduled." />
              <% else %>
                <.huddl_list huddlz={@past_huddlz} empty_message="No past huddlz found." />
                <%= if @past_total_pages > 1 do %>
                  <.pagination
                    current_page={@past_page}
                    total_pages={@past_total_pages}
                    event_name="change_past_page"
                  />
                <% end %>
              <% end %>
            </div>
          </div>

          <.member_list
            members={@members}
            member_count={@member_count}
            owner_id={@group.owner_id}
            current_user={@current_user}
          />
        </div>
      </div>
    </Layouts.app>
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
          # Load first page of past events when switching to past tab
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
    case join_group(socket.assigns.group, socket.assigns.current_user) do
      {:ok, _} ->
        group = Ash.reload!(socket.assigns.group)
        members = get_members(group, socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the group!")
         |> assign(:is_member, true)
         |> assign(:members, members)
         |> assign(:member_count, get_member_count(group))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end

  def handle_event("leave_group", _, socket) do
    case leave_group(socket.assigns.group, socket.assigns.current_user) do
      {:ok, _} ->
        group = Ash.reload!(socket.assigns.group)
        members = get_members(group, socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully left the group")
         |> assign(:is_member, false)
         |> assign(:members, members)
         |> assign(:member_count, get_member_count(group))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug,
           actor: actor,
           load: [:current_image_url, owner: [:current_profile_picture_url]]
         ) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp member?(_group, nil), do: false

  defp member?(group, user) do
    Huddlz.Communities.GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.exists?(authorize?: false)
  end

  defp owner?(_group, nil), do: false

  defp owner?(group, user) do
    group.owner_id == user.id
  end

  defp get_members(group, current_user) do
    if can_see_members?(group, current_user) do
      load_members(group, current_user)
    else
      nil
    end
  end

  defp can_see_members?(group, current_user) do
    # Only members can see member lists
    current_user != nil && member?(group, current_user)
  end

  # Removed unused functions after simplifying role system
  # Only members can see member lists

  defp load_members(group, current_user) do
    # Use get_by_group action which enforces authorization
    GroupMember
    |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
    |> Ash.Query.load(user: [:current_profile_picture_url])
    |> Ash.read!(actor: current_user)
    |> Enum.map(& &1.user)
  end

  defp get_member_count(group) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.count!(authorize?: false)
  end

  defp organizer?(_group, nil), do: false

  defp organizer?(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id and role == :organizer)
    |> Ash.exists?(authorize?: false)
  end

  defp join_group(group, user) do
    GroupMember
    |> Ash.Changeset.for_create(
      :join_group,
      %{
        group_id: group.id,
        user_id: user.id
      },
      actor: user
    )
    |> Ash.create()
  end

  defp leave_group(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
    |> Ash.destroy(action: :leave_group, actor: user)
  end

  defp get_upcoming_group_huddlz(group, user, opts) do
    limit = Keyword.get(opts, :limit, 10)

    page =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:by_group, %{group_id: group.id}, actor: user)
      |> Ash.Query.page(limit: limit)
      |> Ash.read!(actor: user)

    page.results
    |> Ash.load!([:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group],
      actor: user
    )
  end

  defp get_past_group_huddlz_paginated(group, user, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page

    # Use Ash pagination with offset
    page_result =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:past_by_group, %{group_id: group.id}, actor: user)
      |> Ash.Query.page(limit: per_page, offset: offset, count: true)
      |> Ash.read!(actor: user)

    # Load additional fields on the results
    loaded_results =
      page_result.results
      |> Ash.load!([:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group],
        actor: user
      )

    total_pages =
      if page_result.count && page_result.count > 0 do
        ceil(page_result.count / per_page)
      else
        1
      end

    {loaded_results, total_pages}
  end
end
