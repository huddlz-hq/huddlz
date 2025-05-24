defmodule HuddlzWeb.HuddlLive.Show do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"group_id" => group_id, "id" => id}, _, socket) do
    case get_huddl(id, group_id, socket.assigns.current_user) do
      {:ok, huddl} ->
        has_rsvped = check_rsvp(huddl, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:page_title, huddl.title)
         |> assign(:huddl, huddl)
         |> assign(:has_rsvped, has_rsvped)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Huddl not found")
         |> redirect(to: ~p"/groups/#{group_id}")}

      {:error, :not_authorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have access to this huddl")
         |> redirect(to: ~p"/groups")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@huddl.group_id}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@huddl.group.name}
      </.link>

      <.header>
        {@huddl.title}
        <:subtitle>
          <.huddl_status_badge status={@huddl.status} />
          <.huddl_type_badge type={@huddl.event_type} class="ml-2" />
          <%= if @huddl.is_private do %>
            <span class="badge badge-neutral ml-2">Private</span>
          <% end %>
        </:subtitle>
        <:actions>
          <%= if @current_user && @huddl.status == :upcoming do %>
            <%= if @has_rsvped do %>
              <div class="flex items-center gap-4">
                <div class="text-success font-semibold">
                  <.icon name="hero-check-circle" class="h-5 w-5 inline" /> You're attending!
                </div>
                <.button
                  phx-click="cancel_rsvp"
                  phx-disable-with="Cancelling..."
                  class="btn-error btn-sm"
                >
                  Cancel RSVP
                </.button>
              </div>
            <% else %>
              <.button phx-click="rsvp" class="btn-primary">
                RSVP to this huddl
              </.button>
            <% end %>
          <% end %>
        </:actions>
      </.header>

      <div class="mt-8">
        <%= if @huddl.thumbnail_url do %>
          <div class="mb-6">
            <img
              src={@huddl.thumbnail_url}
              alt={@huddl.title}
              class="w-full max-w-2xl rounded-lg shadow-lg"
            />
          </div>
        <% end %>

        <div class="prose max-w-none">
          <div class="grid gap-6 md:grid-cols-2">
            <div>
              <h3>About this huddl</h3>
              <p>{@huddl.description || "No description provided."}</p>
            </div>

            <div>
              <h3>Details</h3>
              <dl class="space-y-2">
                <div>
                  <dt class="font-medium text-gray-500">When</dt>
                  <dd class="flex items-center gap-2">
                    <.icon name="hero-calendar" class="h-4 w-4" />
                    {format_datetime(@huddl.starts_at)}
                    <%= if @huddl.ends_at do %>
                      - {format_time_only(@huddl.ends_at)}
                    <% end %>
                  </dd>
                </div>

                <%= if @huddl.event_type in [:in_person, :hybrid] && @huddl.physical_location do %>
                  <div>
                    <dt class="font-medium text-gray-500">Where</dt>
                    <dd class="flex items-center gap-2">
                      <.icon name="hero-map-pin" class="h-4 w-4" />
                      {@huddl.physical_location}
                    </dd>
                  </div>
                <% end %>

                <%= if @huddl.event_type in [:virtual, :hybrid] do %>
                  <div>
                    <dt class="font-medium text-gray-500">Virtual Access</dt>
                    <dd class="flex items-center gap-2">
                      <.icon name="hero-video-camera" class="h-4 w-4" />
                      <%= if @huddl.visible_virtual_link do %>
                        <a
                          href={@huddl.visible_virtual_link}
                          target="_blank"
                          class="link link-primary"
                        >
                          Join virtually
                        </a>
                      <% else %>
                        <span class="text-base-content/50">
                          <%= if @current_user do %>
                            Virtual link available after RSVP
                          <% else %>
                            Sign in and RSVP to get virtual link
                          <% end %>
                        </span>
                      <% end %>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>
          </div>

          <div class="mt-8">
            <h3>Attendance</h3>
            <p class="flex items-center gap-2">
              <.icon name="hero-user-group" class="h-5 w-5" />
              <%= if @huddl.rsvp_count == 0 do %>
                Be the first to RSVP!
              <% else %>
                {@huddl.rsvp_count} {if @huddl.rsvp_count == 1, do: "person", else: "people"} attending
              <% end %>
            </p>
          </div>

          <div class="mt-8">
            <h3>Group</h3>
            <.link navigate={~p"/groups/#{@huddl.group_id}"} class="link link-primary">
              {@huddl.group.name}
            </.link>
          </div>

          <div class="mt-8">
            <h3>Organized by</h3>
            <p>{@huddl.creator.display_name || @huddl.creator.email}</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("rsvp", _, socket) do
    case rsvp_to_huddl(socket.assigns.huddl, socket.assigns.current_user) do
      {:ok, _} ->
        # Reload the huddl to get updated RSVP count and visible_virtual_link
        {:ok, huddl} =
          get_huddl(
            socket.assigns.huddl.id,
            socket.assigns.huddl.group_id,
            socket.assigns.current_user
          )

        {:noreply,
         socket
         |> put_flash(:info, "Successfully RSVPed to this huddl!")
         |> assign(:huddl, huddl)
         |> assign(:has_rsvped, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to RSVP. Please try again.")}
    end
  end

  defp get_huddl(id, group_id, user) do
    case Huddl
         |> Ash.Query.filter(id == ^id and group_id == ^group_id)
         |> Ash.Query.load([:status, :visible_virtual_link, :group, :creator])
         |> Ash.read_one(actor: user) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, huddl} -> {:ok, huddl}
      {:error, _} -> {:error, :not_authorized}
    end
  end

  defp check_rsvp(_huddl, nil), do: false

  defp check_rsvp(huddl, user) do
    case HuddlAttendee
         |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl.id, user_id: user.id})
         |> Ash.read_one(actor: user) do
      {:ok, nil} -> false
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp rsvp_to_huddl(huddl, user) do
    huddl
    |> Ash.Changeset.for_update(:rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update()
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp format_time_only(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end
end
