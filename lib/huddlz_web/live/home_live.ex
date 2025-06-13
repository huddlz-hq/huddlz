defmodule HuddlzWeb.HomeLive do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.Layouts
  require Ash.Query

  # Ensure current_user is available for the navbar
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Fetch upcoming huddlz
    upcoming_huddlz =
      Huddl
      |> Ash.Query.for_read(:upcoming)
      |> Ash.read!(actor: actor)

    # Fetch past huddlz
    past_huddlz =
      Huddl
      |> Ash.Query.for_read(:past)
      |> Ash.read!(actor: actor)

    socket =
      socket
      |> assign(:upcoming_huddlz, upcoming_huddlz)
      |> assign(:past_huddlz, past_huddlz)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Find your huddl</h1>
        
    <!-- Upcoming Huddlz Section -->
        <section class="mb-12">
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Upcoming Huddlz</h2>
          <%= if @upcoming_huddlz == [] do %>
            <p class="text-gray-600">No upcoming huddlz found</p>
          <% else %>
            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <%= for huddl <- @upcoming_huddlz do %>
                <.huddl_display_card huddl={huddl} />
              <% end %>
            </div>
          <% end %>
        </section>
        
    <!-- Past Huddlz Section -->
        <section>
          <h2 class="text-2xl font-semibold text-gray-800 mb-4">Past Huddlz</h2>
          <%= if @past_huddlz == [] do %>
            <p class="text-gray-600">No past huddlz found</p>
          <% else %>
            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <%= for huddl <- @past_huddlz do %>
                <.huddl_display_card huddl={huddl} past={true} />
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp huddl_display_card(assigns) do
    ~H"""
    <div class={"bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow " <> if assigns[:past], do: "opacity-75", else: ""}>
      <h3 class="text-xl font-semibold mb-2">{@huddl.title}</h3>
      <%= if @huddl.description do %>
        <p class="text-gray-600 mb-3 line-clamp-2">{@huddl.description}</p>
      <% end %>

      <div class="space-y-2 text-sm text-gray-500">
        <div class="flex items-center gap-2">
          <.icon name="hero-calendar-days" class="w-4 h-4" />
          <span>{format_datetime(@huddl.starts_at)}</span>
        </div>

        <%= if @huddl.physical_location do %>
          <div class="flex items-center gap-2">
            <.icon name="hero-map-pin" class="w-4 h-4" />
            <span>{@huddl.physical_location}</span>
          </div>
        <% end %>

        <%= if @huddl.virtual_link do %>
          <div class="flex items-center gap-2">
            <.icon name="hero-video-camera" class="w-4 h-4" />
            <span>Virtual event</span>
          </div>
        <% end %>

        <div class="flex items-center gap-2">
          <.icon name="hero-user-group" class="w-4 h-4" />
          <span>{@huddl.rsvp_count} attending</span>
        </div>

        <%= if @huddl.group do %>
          <div class="flex items-center gap-2">
            <.icon name="hero-building-office" class="w-4 h-4" />
            <span>{@huddl.group.name}</span>
          </div>
        <% end %>
      </div>

      <div class="mt-4">
        <%= if @huddl.group do %>
          <.link
            navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}"}
            class="text-indigo-600 hover:text-indigo-800 font-medium"
          >
            View details →
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
