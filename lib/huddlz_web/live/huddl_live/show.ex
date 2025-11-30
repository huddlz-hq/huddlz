defmodule HuddlzWeb.HuddlLive.Show do
  @moduledoc """
  LiveView for displaying a huddl's details, RSVP status, and attendee count.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    case get_huddl(id, group_slug, socket.assigns.current_user) do
      {:ok, huddl} ->
        has_rsvped = check_rsvp(huddl, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:page_title, huddl.title)
         |> assign(:huddl, huddl)
         |> assign(:has_rsvped, has_rsvped)
         |> assign(:is_creator, creator?(huddl, socket.assigns.current_user))}

      {:error, :not_found} ->
        {:noreply,
         handle_error(socket, :not_found,
           resource_name: "Huddl",
           fallback_path: ~p"/groups/#{group_slug}"
         )}

      {:error, :not_authorized} ->
        {:noreply,
         handle_error(socket, :not_authorized,
           resource_name: "huddl",
           action: "access",
           fallback_path: ~p"/groups"
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@huddl.group.slug}"}
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
          <%= if @is_creator do %>
            <.link
              navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}/edit"}
              class="btn btn-ghost"
            >
              <.icon name="hero-pencil" class="h-4 w-4" /> Edit Huddl
            </.link>
            <button
              phx-click="delete_huddl"
              data-confirm="Are you sure you want to delete this huddl?"
              class="btn btn-error"
            >
              <.icon name="hero-trash" class="h-4 w-4" /> Delete Huddl
            </button>
          <% end %>
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
        <%= if @huddl.display_image_url do %>
          <div class="mb-6">
            <img
              src={HuddlImages.url(@huddl.display_image_url)}
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
                  <dt class="font-medium text-base-content/70">When</dt>
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
                    <dt class="font-medium text-base-content/70">Where</dt>
                    <dd class="flex items-center gap-2">
                      <.icon name="hero-map-pin" class="h-4 w-4" />
                      {@huddl.physical_location}
                    </dd>
                  </div>
                <% end %>

                <%= if @huddl.event_type in [:virtual, :hybrid] do %>
                  <div>
                    <dt class="font-medium text-base-content/70">Virtual Access</dt>
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
            <.link navigate={~p"/groups/#{@huddl.group.slug}"} class="link link-primary">
              {@huddl.group.name}
            </.link>
          </div>

          <div class="mt-8">
            <h3>Organized by</h3>
            <div class="flex items-center gap-3 mt-2">
              <.avatar user={@huddl.creator} size={:sm} />
              <span>{@huddl.creator.display_name || @huddl.creator.email}</span>
            </div>
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
            socket.assigns.huddl.group.slug,
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

  @impl true
  def handle_event("cancel_rsvp", _, socket) do
    case cancel_rsvp(socket.assigns.huddl, socket.assigns.current_user) do
      {:ok, _} ->
        # Reload the huddl to get updated RSVP count
        {:ok, huddl} =
          get_huddl(
            socket.assigns.huddl.id,
            socket.assigns.huddl.group.slug,
            socket.assigns.current_user
          )

        {:noreply,
         socket
         |> put_flash(:info, "RSVP cancelled successfully")
         |> assign(:huddl, huddl)
         |> assign(:has_rsvped, false)}

      {:error, %Ash.Error.Forbidden{}} ->
        {:noreply, put_flash(socket, :error, "You can only cancel your own RSVP.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel RSVP. Please try again.")}
    end
  end

  def handle_event("delete_huddl", _, socket) do
    Ash.destroy!(socket.assigns.huddl, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "Huddl deleted successfully!")
     |> redirect(to: ~p"/groups/#{socket.assigns.huddl.group.slug}")}
  end

  defp get_huddl(id, group_slug, user) do
    # Get the huddl and verify it belongs to the group with the given slug
    case Huddl
         |> Ash.Query.filter(id == ^id)
         |> Ash.Query.load([
           :status,
           :visible_virtual_link,
           :display_image_url,
           :group,
           creator: [:current_profile_picture_url]
         ])
         |> Ash.read_one(actor: user) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, huddl} ->
        # Verify the huddl belongs to the group with the given slug
        if huddl.group.slug == group_slug do
          {:ok, huddl}
        else
          {:error, :not_found}
        end

      {:error, _} ->
        {:error, :not_authorized}
    end
  end

  defp creator?(_huddl, nil), do: false

  defp creator?(huddl, user) do
    huddl.creator_id == user.id
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

  defp cancel_rsvp(huddl, user) do
    huddl
    |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update()
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp format_time_only(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end
end
