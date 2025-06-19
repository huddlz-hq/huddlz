defmodule HuddlzWeb.GroupLive.Show do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.GroupMember
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    with {:ok, group} <- get_group_by_slug(slug, socket.assigns.current_user),
         :ok <- check_group_access(group, socket.assigns.current_user) do
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
    else
      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Group not found")
         |> redirect(to: ~p"/groups")}

      {:error, :not_authorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "Group not found")
         |> redirect(to: ~p"/groups")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link navigate={~p"/groups"} class="text-sm font-semibold leading-6 hover:underline">
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to groups
      </.link>

      <.header>
        {@group.name}
        <:subtitle>
          <%= if @group.is_public do %>
            <span class="badge badge-secondary">Public Group</span>
          <% else %>
            <span class="badge">Private Group</span>
          <% end %>
          <%= if @is_owner do %>
            <span class="badge badge-primary ml-2">Owner</span>
          <% end %>
        </:subtitle>
        <:actions>
          <%= if @current_user do %>
            <%= if @is_owner do %>
              <.link navigate={~p"/groups/#{@group.slug}/edit"} class="btn btn-ghost">
                <.icon name="hero-pencil" class="h-4 w-4" /> Edit Group
              </.link>
            <% end %>

            <%= if @is_owner || @is_organizer do %>
              <.link navigate={~p"/groups/#{@group.slug}/huddlz/new"} class="btn btn-primary">
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
        <%= if @group.image_url do %>
          <div class="mb-6">
            <img
              src={@group.image_url}
              alt={@group.name}
              class="w-full max-w-2xl rounded-lg shadow-lg"
            />
          </div>
        <% end %>

        <div class="prose max-w-none">
          <div class="grid gap-6 md:grid-cols-2">
            <div>
              <h3>Description</h3>
              <p>{@group.description || "No description provided."}</p>
            </div>

            <%= if @group.location do %>
              <div>
                <h3>Location</h3>
                <p class="flex items-center gap-2">
                  <.icon name="hero-map-pin" class="h-5 w-5" />
                  {@group.location}
                </p>
              </div>
            <% end %>
          </div>

          <div class="mt-8">
            <h3>Group Details</h3>
            <dl class="grid gap-4 sm:grid-cols-2">
              <div>
                <dt class="font-medium text-gray-500">Created</dt>
                <dd>{format_date(@group.created_at)}</dd>
              </div>
              <div>
                <dt class="font-medium text-gray-500">Owner</dt>
                <dd>{@group.owner.display_name || @group.owner.email}</dd>
              </div>
            </dl>
          </div>

          <div class="mt-8">
            <h3>Events</h3>
            
    <!-- Tabs -->
            <div class="tabs tabs-boxed mt-4">
              <button
                class={["tab", if(@active_tab == "upcoming", do: "tab-active", else: "")]}
                phx-click="switch_tab"
                phx-value-tab="upcoming"
              >
                Upcoming Events
              </button>
              <button
                class={["tab", if(@active_tab == "past", do: "tab-active", else: "")]}
                phx-click="switch_tab"
                phx-value-tab="past"
              >
                Past Events
              </button>
            </div>
            
    <!-- Tab Content -->
            <div class="mt-6">
              <%= if @active_tab == "upcoming" do %>
                <%= if Enum.empty?(@upcoming_huddlz) do %>
                  <p class="text-gray-600 mt-4">No upcoming huddlz scheduled.</p>
                <% else %>
                  <div class="space-y-4">
                    <%= for huddl <- @upcoming_huddlz do %>
                      <.huddl_card huddl={huddl} />
                    <% end %>
                  </div>
                <% end %>
              <% else %>
                <%= if Enum.empty?(@past_huddlz) do %>
                  <p class="text-gray-600 mt-4">No past huddlz found.</p>
                <% else %>
                  <div class="space-y-4">
                    <%= for huddl <- @past_huddlz do %>
                      <.huddl_card huddl={huddl} />
                    <% end %>
                  </div>
                  
    <!-- Pagination -->
                  <%= if @past_total_pages > 1 do %>
                    <.pagination
                      current_page={@past_page}
                      total_pages={@past_total_pages}
                      event_name="change_past_page"
                    />
                  <% end %>
                <% end %>
              <% end %>
            </div>
          </div>

          <div class="mt-8">
            <h3>Members ({@member_count})</h3>
            <%= if @members do %>
              <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <%= for member <- @members do %>
                  <div class="flex items-center gap-3 rounded-lg border p-3">
                    <div class="flex-1">
                      <p class="font-medium">
                        {member.display_name || "User"}
                        <%= if member.id == @group.owner_id do %>
                          <span class="text-xs font-normal text-gray-500">(Owner)</span>
                        <% end %>
                      </p>
                      <p class="text-sm text-gray-500">{member.email}</p>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-600">Members list is only visible to verified users.</p>
            <% end %>
          </div>
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
    case Huddlz.Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp check_group_access(group, user) do
    cond do
      group.is_public -> :ok
      user == nil -> {:error, :not_authorized}
      owner?(group, user) -> :ok
      member?(group, user) -> :ok
      true -> {:error, :not_authorized}
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

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp get_members(group, current_user) do
    if can_see_members?(group, current_user) do
      load_members(group)
    else
      nil
    end
  end

  defp can_see_members?(group, current_user) do
    owner_or_organizer?(group, current_user) ||
      verified_member?(group, current_user) ||
      verified_non_member_of_public_group?(group, current_user)
  end

  defp owner_or_organizer?(group, current_user) do
    owner?(group, current_user) || organizer?(group, current_user)
  end

  defp verified_member?(group, current_user) do
    member?(group, current_user) && current_user && current_user.role == :verified
  end

  defp verified_non_member_of_public_group?(group, current_user) do
    group.is_public && current_user && current_user.role == :verified
  end

  defp load_members(group) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.load(:user)
    |> Ash.read!(authorize?: false)
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
    |> Ash.load!([:status, :visible_virtual_link, :group], actor: user)
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
      |> Ash.load!([:status, :visible_virtual_link, :group], actor: user)

    total_pages =
      if page_result.count && page_result.count > 0 do
        ceil(page_result.count / per_page)
      else
        1
      end

    {loaded_results, total_pages}
  end
end
