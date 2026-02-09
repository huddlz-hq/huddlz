defmodule HuddlzWeb.CommunityComponents do
  @moduledoc """
  Reusable UI components for communities domain (groups and huddlz).
  """
  use Phoenix.Component
  use HuddlzWeb, :verified_routes

  import HuddlzWeb.CoreComponents, only: [huddl_card: 1, avatar: 1, icon: 1]

  alias Huddlz.Storage.GroupImages

  @doc """
  Renders a list of huddlz with empty state handling.

  ## Examples

      <.huddl_list huddlz={@upcoming_huddlz} empty_message="No upcoming huddlz scheduled." />
      <.huddl_list huddlz={@huddlz} show_group={true} empty_message="No huddlz found." />
  """
  attr :huddlz, :list, required: true
  attr :empty_message, :string, default: "No huddlz found."
  attr :show_group, :boolean, default: false

  def huddl_list(assigns) do
    ~H"""
    <%= if Enum.empty?(@huddlz) do %>
      <p class="text-base-content/50 mt-4 text-sm">{@empty_message}</p>
    <% else %>
      <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for huddl <- @huddlz do %>
          <.huddl_card huddl={huddl} show_group={@show_group} />
        <% end %>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a group card with 16:9 banner image and content below.

  ## Examples

      <.group_card group={group} />
  """
  attr :group, :map, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def group_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/groups/#{@group.slug}"}
      class={[
        "border border-base-300 overflow-hidden hover:border-primary/30 transition-colors group flex flex-col",
        @class
      ]}
      {@rest}
    >
      <div class="aspect-video overflow-hidden relative bg-base-200 flex-shrink-0">
        <%= if @group.current_image_url do %>
          <img
            src={GroupImages.url(@group.current_image_url)}
            alt={@group.name}
            class="w-full h-full object-cover"
          />
        <% else %>
          <div class="w-full h-full bg-base-100 flex items-center justify-center">
            <span class="text-2xl font-bold text-base-content/30 text-center px-4 line-clamp-2">
              {@group.name}
            </span>
          </div>
        <% end %>
      </div>
      <div class="p-4 flex-1">
        <h2 class="font-display tracking-tight">{@group.name}</h2>
        <p class="text-sm text-base-content/40 line-clamp-2 mt-1">
          {@group.description || "No description provided."}
        </p>
        <p :if={@group.location} class="text-xs text-base-content/50 mt-2 flex items-center gap-1">
          <.icon name="hero-map-pin" class="h-3 w-3" /> {@group.location}
        </p>
      </div>
    </.link>
    """
  end

  @doc """
  Renders a grid of group cards with empty state handling.

  ## Examples

      <.group_list groups={@groups} empty_message="No groups found." />
  """
  attr :groups, :list, required: true
  attr :empty_message, :string, default: "No groups found."

  def group_list(assigns) do
    ~H"""
    <%= if Enum.empty?(@groups) do %>
      <p class="text-base-content/50 mt-4 text-sm">{@empty_message}</p>
    <% else %>
      <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for group <- @groups do %>
          <.group_card group={group} />
        <% end %>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a member card showing user display name and optional owner badge.

  ## Examples

      <.member_card member={member} is_owner={member.id == @group.owner_id} />
  """
  attr :member, :map, required: true
  attr :is_owner, :boolean, default: false

  def member_card(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-2">
      <.avatar user={@member} size={:sm} />
      <div class="flex-1 min-w-0">
        <p class="font-medium text-sm truncate">
          {@member.display_name || "User"}
        </p>
      </div>
      <%= if @is_owner do %>
        <span class="mono-label text-primary">
          Owner
        </span>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a grid of group members with permission-based visibility.

  ## Examples

      <.member_list
        members={@members}
        member_count={@member_count}
        owner_id={@group.owner_id}
        current_user={@current_user}
      />
  """
  attr :members, :list, default: nil
  attr :member_count, :integer, required: true
  attr :owner_id, :string, required: true
  attr :current_user, :map, default: nil

  def member_list(assigns) do
    ~H"""
    <div class="mt-10">
      <h3 class="font-display text-lg tracking-tight text-glow flex items-center gap-2">
        <.icon name="hero-users" class="w-5 h-5 text-base-content/40" /> Members
        <span class="text-sm font-body font-normal text-base-content/50">({@member_count})</span>
      </h3>
      <%= if @members do %>
        <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <%= for member <- @members do %>
            <.member_card member={member} is_owner={member.id == @owner_id} />
          <% end %>
        </div>
      <% else %>
        <p class="text-base-content/50 text-sm mt-3">
          <%= if @current_user do %>
            Only members can see the member list.
          <% else %>
            Please sign in to see the member list.
          <% end %>
        </p>
      <% end %>
    </div>
    """
  end
end
