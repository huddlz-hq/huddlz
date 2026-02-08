defmodule HuddlzWeb.CommunityComponents do
  @moduledoc """
  Reusable UI components for communities domain (groups and huddlz).
  """
  use Phoenix.Component

  import HuddlzWeb.CoreComponents, only: [huddl_card: 1, avatar: 1, icon: 1]

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
      <div class="space-y-4">
        <%= for huddl <- @huddlz do %>
          <.huddl_card huddl={huddl} show_group={@show_group} />
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
