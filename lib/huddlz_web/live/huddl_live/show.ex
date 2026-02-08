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
      <.header>
        {@huddl.title}
        <:subtitle>
          <%= if @huddl.is_private do %>
            <span class="text-xs px-2.5 py-1 bg-base-300 text-base-content/50 font-medium">
              Private
            </span>
          <% end %>
        </:subtitle>
        <:actions>
          <%= if @is_creator do %>
            <.link
              navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}/edit"}
              class="inline-flex items-center gap-1.5 text-sm font-medium text-base-content/50 hover:text-base-content transition-colors"
            >
              <.icon name="hero-pencil" class="h-4 w-4" /> Edit Huddl
            </.link>
            <button
              phx-click="delete_huddl"
              data-confirm="Are you sure you want to delete this huddl?"
              class="px-4 py-2 text-sm font-medium bg-error text-error-content btn-neon transition-all inline-flex items-center gap-1.5"
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
                <button
                  phx-click="cancel_rsvp"
                  phx-disable-with="Cancelling..."
                  class="px-3 py-1.5 text-xs font-medium bg-error/10 text-error hover:bg-error/20 transition-colors"
                >
                  Cancel RSVP
                </button>
              </div>
            <% else %>
              <.button phx-click="rsvp">
                RSVP to this huddl
              </.button>
            <% end %>
          <% end %>
        </:actions>
      </.header>

      <div class="mt-8">
        <div class="mb-6">
          <%= if @huddl.display_image_url do %>
            <div class="border border-base-300 overflow-hidden">
              <img
                src={HuddlImages.url(@huddl.display_image_url)}
                alt={@huddl.title}
                class="w-full aspect-video object-cover"
              />
            </div>
          <% else %>
            <div class="w-full aspect-video bg-base-100 border border-base-300 overflow-hidden flex items-center justify-center">
              <span class="text-4xl font-bold text-base-content/40 text-center px-8 line-clamp-2">
                {@huddl.title}
              </span>
            </div>
          <% end %>
        </div>

        <p class="text-base-content/60">
          {@huddl.description || "No description provided."}
        </p>

        <dl class="mt-6">
          <div class="flex items-start gap-3 py-3">
            <dt class="w-32 shrink-0 font-medium text-base-content/50">Status</dt>
            <dd class={["flex items-center gap-2", status_text_class(@huddl.status)]}>
              <.icon name={status_icon(@huddl.status)} class="h-4 w-4" />
              {@huddl.status |> to_string() |> String.replace("_", " ") |> String.capitalize()}
            </dd>
          </div>

          <div class="flex items-start gap-3 py-3">
            <dt class="w-32 shrink-0 font-medium text-base-content/50">Type</dt>
            <dd class="flex items-center gap-2">
              <.icon name={type_detail_icon(@huddl.event_type)} class="h-4 w-4" />
              {@huddl.event_type |> to_string() |> String.replace("_", " ") |> String.capitalize()}
            </dd>
          </div>

          <div class="flex items-start gap-3 py-3">
            <dt class="w-32 shrink-0 font-medium text-base-content/50">When</dt>
            <dd class="flex items-center gap-2">
              <.icon name="hero-calendar" class="h-4 w-4" />
              {format_datetime(@huddl.starts_at)}
              <%= if @huddl.ends_at do %>
                - {format_time_only(@huddl.ends_at)}
              <% end %>
            </dd>
          </div>

          <%= if @huddl.event_type in [:in_person, :hybrid] && @huddl.physical_location do %>
            <div class="flex items-start gap-3 py-3">
              <dt class="w-32 shrink-0 font-medium text-base-content/50">Where</dt>
              <dd class="flex items-center gap-2">
                <.icon name="hero-map-pin" class="h-4 w-4" />
                {@huddl.physical_location}
              </dd>
            </div>
          <% end %>

          <%= if @huddl.event_type in [:virtual, :hybrid] do %>
            <div class="flex items-start gap-3 py-3">
              <dt class="w-32 shrink-0 font-medium text-base-content/50">Virtual Access</dt>
              <dd class="flex items-center gap-2">
                <.icon name="hero-video-camera" class="h-4 w-4" />
                <%= cond do %>
                  <% @huddl.status == :completed -> %>
                    <span class="text-base-content/50">Link expired</span>
                  <% @huddl.visible_virtual_link -> %>
                    <a
                      href={@huddl.visible_virtual_link}
                      target="_blank"
                      class="text-primary hover:underline font-medium"
                    >
                      Join virtually
                    </a>
                  <% @current_user -> %>
                    <span class="text-base-content/50">
                      Virtual link available after RSVP
                    </span>
                  <% true -> %>
                    <span class="text-base-content/50">
                      Sign in and RSVP to get virtual link
                    </span>
                <% end %>
              </dd>
            </div>
          <% end %>

          <%= if @huddl.status != :completed do %>
            <div class="flex items-start gap-3 py-3">
              <dt class="w-32 shrink-0 font-medium text-base-content/50">Attendance</dt>
              <dd class="flex items-center gap-2">
                <.icon name="hero-user-group" class="h-4 w-4" />
                <%= if @huddl.rsvp_count == 0 do %>
                  Be the first to RSVP!
                <% else %>
                  {@huddl.rsvp_count} {if @huddl.rsvp_count == 1, do: "person", else: "people"} attending
                <% end %>
              </dd>
            </div>
          <% else %>
            <div class="flex items-start gap-3 py-3">
              <dt class="w-32 shrink-0 font-medium text-base-content/50">Attended</dt>
              <dd class="flex items-center gap-2">
                <.icon name="hero-user-group" class="h-4 w-4" />
                <%= if @huddl.rsvp_count == 0 do %>
                  No one attended
                <% else %>
                  {@huddl.rsvp_count} {if @huddl.rsvp_count == 1, do: "person", else: "people"} attended
                <% end %>
              </dd>
            </div>
          <% end %>

          <div class="flex items-start gap-3 py-3">
            <dt class="w-32 shrink-0 font-medium text-base-content/50">Organized by</dt>
            <dd class="flex items-center gap-2">
              <.avatar user={@huddl.creator} size={:sm} />
              {@huddl.creator.display_name || @huddl.creator.email}
            </dd>
          </div>
        </dl>
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

  defp status_text_class(:upcoming), do: "text-primary"
  defp status_text_class(:in_progress), do: "text-success"
  defp status_text_class(:completed), do: "text-base-content/50"
  defp status_text_class(:cancelled), do: "text-error"
  defp status_text_class(_), do: ""

  defp status_icon(:upcoming), do: "hero-clock"
  defp status_icon(:in_progress), do: "hero-play-circle"
  defp status_icon(:completed), do: "hero-check-circle"
  defp status_icon(:cancelled), do: "hero-x-circle"
  defp status_icon(_), do: "hero-question-mark-circle"

  defp type_detail_icon(:in_person), do: "hero-map-pin"
  defp type_detail_icon(:virtual), do: "hero-video-camera"
  defp type_detail_icon(:hybrid), do: "hero-globe-alt"
  defp type_detail_icon(_), do: "hero-calendar"
end
