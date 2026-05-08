defmodule HuddlzWeb.CommunityComponents do
  @moduledoc """
  Reusable UI components for communities domain (groups and huddlz).

  Reconciled with the search-organize prototype: cards use
  `rounded-hz-surface`, badges use `rounded-hz-control`, titles use Inter
  heavy weights instead of Space Mono, and status pills use the prototype's
  uppercase-mono badge.
  """
  use Phoenix.Component
  use HuddlzWeb, :verified_routes

  import HuddlzWeb.CoreComponents, only: [avatar: 1, humanize: 1, icon: 1]

  alias Huddlz.Storage.GroupImages
  alias Huddlz.Storage.HuddlImages

  @doc """
  Renders a list of huddlz with empty state handling.
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
  """
  attr :group, :map, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def group_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/groups/#{@group.slug}"}
      class={[
        "border border-base-300 rounded-hz-surface overflow-hidden bg-base-200 hover:border-primary/50 transition-colors group flex flex-col",
        @class
      ]}
      {@rest}
    >
      <div class="aspect-video overflow-hidden relative bg-base-300 flex-shrink-0">
        <%= if @group.current_image_url do %>
          <img
            src={GroupImages.url(@group.current_image_url)}
            alt={@group.name}
            class="w-full h-full object-cover"
          />
        <% else %>
          <div class="w-full h-full bg-base-100 flex items-center justify-center">
            <span class="text-2xl font-extrabold text-base-content/30 text-center px-4 line-clamp-2">
              {@group.name}
            </span>
          </div>
        <% end %>
      </div>
      <div class="p-4 flex-1">
        <h2 class="text-base font-extrabold leading-snug text-base-content">{@group.name}</h2>
        <p class="text-sm text-base-content/50 line-clamp-2 mt-1.5 leading-relaxed">
          {@group.description || "No description provided."}
        </p>
        <p :if={@group.location} class="text-xs text-base-content/50 mt-3 flex items-center gap-1">
          <.icon name="hero-map-pin" class="h-3 w-3" /> {@group.location}
        </p>
      </div>
    </.link>
    """
  end

  @doc """
  Renders a grid of group cards with empty state handling.
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
  Renders a huddl card with 16:9 banner image and content below.
  """
  attr :huddl, :map, required: true
  attr :show_group, :boolean, default: false
  attr :distance, :float, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def huddl_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}"}
      class={[
        "border border-base-300 rounded-hz-surface overflow-hidden bg-base-200 hover:border-primary/50 transition-colors group flex flex-col",
        @class
      ]}
      {@rest}
    >
      <div class="aspect-video overflow-hidden relative bg-base-300 flex-shrink-0">
        <%= if @huddl.display_image_url do %>
          <img
            src={HuddlImages.url(@huddl.display_image_url)}
            alt={@huddl.title}
            class="w-full h-full object-cover"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center bg-base-100">
            <span class="text-base-content/30 text-lg font-extrabold text-center px-3 line-clamp-2">
              {@huddl.title}
            </span>
          </div>
        <% end %>
        <div :if={@huddl.status not in [:upcoming, :completed]} class="absolute top-2 right-2">
          <.huddl_status_badge status={@huddl.status} />
        </div>
        <div :if={@huddl.is_private} class="absolute top-2 left-2">
          <.huddl_badge>Private</.huddl_badge>
        </div>
      </div>
      <div class="p-4 flex-1 flex flex-col">
        <h3 class="text-base font-extrabold leading-snug text-base-content">{@huddl.title}</h3>
        <%= if @show_group && Map.has_key?(@huddl, :group) do %>
          <p class="text-xs text-base-content/50 mt-1 flex items-center gap-1">
            <.icon name="hero-user-group" class="h-3 w-3" />
            {@huddl.group.name}
          </p>
        <% end %>
        <p class="text-sm text-base-content/50 mt-1.5 line-clamp-2 leading-relaxed">
          {truncate(@huddl.description || "No description provided", 150)}
        </p>
        <div class="flex flex-wrap gap-x-3 gap-y-1 mt-3 text-xs text-base-content/50">
          <span class="flex items-center gap-1">
            <.icon name={type_icon(@huddl.event_type)} class="h-3.5 w-3.5" />
            {humanize(@huddl.event_type)}
          </span>
          <span class="flex items-center gap-1">
            <.icon name="hero-calendar" class="h-3.5 w-3.5" />
            {format_datetime(@huddl.starts_at)}
          </span>
          <%= if @huddl.event_type in [:in_person, :hybrid] && @huddl.physical_location do %>
            <span class="flex items-center gap-1">
              <.icon name="hero-map-pin" class="h-3.5 w-3.5" />
              {@huddl.physical_location}
            </span>
          <% end %>
          <%= if @huddl.max_attendees || @huddl.rsvp_count > 0 do %>
            <span class="flex items-center gap-1">
              <.icon name="hero-user-group" class="h-3.5 w-3.5" />
              <%= if @huddl.max_attendees do %>
                {capacity_label(@huddl)}
              <% else %>
                {@huddl.rsvp_count} attending
              <% end %>
            </span>
          <% end %>
          <%= if @distance do %>
            <span class="flex items-center gap-1 text-primary/80">
              <.icon name="hero-map-pin" class="h-3.5 w-3.5" />
              {format_distance(@distance)}
            </span>
          <% end %>
        </div>
        <%= if @huddl.max_attendees do %>
          <div class="mt-3">
            <div class="flex items-center justify-between text-xs">
              <span class={capacity_status_class(@huddl)}>{capacity_status(@huddl)}</span>
            </div>
            <div class="mt-1.5 h-1.5 bg-base-300 rounded-hz-control overflow-hidden">
              <div class="h-full bg-primary" style={"width: #{capacity_percent(@huddl)}%"}></div>
            </div>
          </div>
        <% end %>
      </div>
    </.link>
    """
  end

  @doc """
  Renders a small uppercase-mono pill — the prototype's badge vocabulary.
  Use directly, or via `huddl_status_badge` / `huddl_type_badge`.
  """
  attr :variant, :string, default: "default", values: ~w(default cyan outline danger)
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def huddl_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center min-h-[22px] px-2 rounded-hz-control text-[10px] font-extrabold uppercase tracking-wider leading-none",
      huddl_badge_classes(@variant),
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp huddl_badge_classes("default"),
    do: "border border-base-300 text-base-content/70 bg-base-200"

  defp huddl_badge_classes("cyan"), do: "border border-primary text-primary bg-primary/10"
  defp huddl_badge_classes("outline"), do: "border border-base-300 text-base-content/60"
  defp huddl_badge_classes("danger"), do: "border border-error text-error"

  @doc """
  Renders a huddl status badge.
  """
  attr :status, :atom, required: true
  attr :class, :string, default: nil

  def huddl_status_badge(assigns) do
    ~H"""
    <.huddl_badge variant={status_badge_variant(@status)} class={@class}>
      {humanize(@status)}
    </.huddl_badge>
    """
  end

  @doc """
  Renders a huddl type badge.
  """
  attr :type, :atom, required: true
  attr :class, :string, default: nil

  def huddl_type_badge(assigns) do
    ~H"""
    <.huddl_badge variant="outline" class={@class}>
      <.icon name={type_icon(@type)} class="h-3 w-3 mr-1" />
      {humanize(@type)}
    </.huddl_badge>
    """
  end

  @doc """
  Renders a member card showing user display name and optional owner badge.
  """
  attr :member, :map, required: true
  attr :is_owner, :boolean, default: false

  def member_card(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-2">
      <.avatar user={@member} size={:sm} />
      <div class="flex-1 min-w-0">
        <p class="font-bold text-sm truncate">
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
  """
  attr :members, :list, default: nil
  attr :member_count, :integer, required: true
  attr :owner_id, :string, required: true
  attr :current_user, :map, default: nil

  def member_list(assigns) do
    ~H"""
    <div class="mt-10">
      <h3 class="text-lg font-extrabold tracking-tight text-base-content flex items-center gap-2">
        <.icon name="hero-users" class="w-5 h-5 text-base-content/40" /> Members
        <span class="text-sm font-normal text-base-content/50">({@member_count})</span>
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

  # Helper functions

  defp status_badge_variant(:upcoming), do: "cyan"
  defp status_badge_variant(:in_progress), do: "cyan"
  defp status_badge_variant(:completed), do: "default"
  defp status_badge_variant(_), do: "default"

  defp type_icon(:in_person), do: "hero-map-pin"
  defp type_icon(:virtual), do: "hero-video-camera"
  defp type_icon(:hybrid), do: "hero-globe-alt"
  defp type_icon(_), do: "hero-calendar"

  def event_full?(%{max_attendees: nil}), do: false
  def event_full?(huddl), do: huddl.rsvp_count >= huddl.max_attendees

  def capacity_label(huddl), do: "#{huddl.rsvp_count}/#{huddl.max_attendees} spots filled"

  def capacity_percent(%{max_attendees: nil}), do: 0

  def capacity_percent(huddl) do
    min(round(huddl.rsvp_count / huddl.max_attendees * 100), 100)
  end

  def capacity_status(huddl), do: capacity_status_for_tier(capacity_tier(huddl))
  def capacity_status_class(huddl), do: capacity_status_class_for_tier(capacity_tier(huddl))

  defp capacity_tier(huddl) do
    cond do
      event_full?(huddl) -> :full
      capacity_percent(huddl) >= 80 -> :almost_full
      capacity_percent(huddl) >= 50 -> :filling_up
      true -> :plenty
    end
  end

  defp capacity_status_for_tier(:full), do: "Event Full"
  defp capacity_status_for_tier(:almost_full), do: "Almost full"
  defp capacity_status_for_tier(:filling_up), do: "Filling up"
  defp capacity_status_for_tier(:plenty), do: "Plenty of space"

  defp capacity_status_class_for_tier(:full), do: "font-bold text-error"
  defp capacity_status_class_for_tier(:almost_full), do: "font-bold text-warning"
  defp capacity_status_class_for_tier(_), do: "font-bold text-success"

  defp truncate(text, max_length) when is_binary(text) and byte_size(text) > max_length do
    String.slice(text, 0, max_length) <> "..."
  end

  defp truncate(text, _), do: text

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y · %I:%M %p")
  end

  defp format_distance(miles) when miles < 1, do: "< 1 mi"
  defp format_distance(miles), do: "#{Float.round(miles * 1.0, 1)} mi"
end
