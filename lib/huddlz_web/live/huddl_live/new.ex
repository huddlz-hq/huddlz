defmodule HuddlzWeb.HuddlLive.New do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"group_slug" => group_slug}, _session, socket) do
    with {:ok, group} <- get_group_by_slug(group_slug, socket.assigns.current_user),
         :ok <- check_can_create_huddl(group, socket.assigns.current_user) do
      # Initialize form with defaults
      form =
        AshPhoenix.Form.for_create(Huddl, :create,
          domain: Huddlz.Communities,
          actor: socket.assigns.current_user,
          params: %{
            "group_id" => group.id,
            "creator_id" => socket.assigns.current_user.id
          }
        )

      {:ok,
       socket
       |> assign(:page_title, "Create New Huddl")
       |> assign(:group, group)
       |> assign(:form, to_form(form))
       |> assign(:show_virtual_link, false)
       |> assign(:show_physical_location, true)}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Group not found")
         |> redirect(to: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have permission to create huddlz for this group")
         |> redirect(to: ~p"/groups/#{group_slug}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@group.slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@group.name}
      </.link>

      <.header>
        Create New Huddl
        <:subtitle>
          Creating an event for <span class="font-semibold">{@group.name}</span>
        </:subtitle>
      </.header>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:starts_at]} type="datetime-local" label="Start Date & Time" required />
          <.input field={@form[:ends_at]} type="datetime-local" label="End Date & Time" required />
        </div>

        <.input field={@form[:is_recurring]} type="checkbox" label="Make this a recurring event" />

        <%= if @form[:is_recurring].value do %>
          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={@form[:frequency]}
              type="select"
              label="Frequency"
              options={[
                {"Weekly", "weekly"},
                {"Monthly", "monthly"}
              ]}
              required
            />
            <.input field={@form[:repeat_until]} type="date" label="Repeat Until" required />
          </div>
        <% end %>

        <.input
          field={@form[:event_type]}
          type="select"
          label="Event Type"
          options={[
            {"In-Person", "in_person"},
            {"Virtual", "virtual"},
            {"Hybrid (Both In-Person and Virtual)", "hybrid"}
          ]}
          required
          phx-change="event_type_changed"
        />

        <%= if @show_physical_location do %>
          <.input
            field={@form[:physical_location]}
            type="text"
            label="Physical Location"
            placeholder="e.g., 123 Main St, City, State"
          />
        <% end %>

        <%= if @show_virtual_link do %>
          <.input
            field={@form[:virtual_link]}
            type="text"
            label="Virtual Meeting Link"
            placeholder="e.g., https://zoom.us/j/123456789"
          />
        <% end %>

        <%= if @group.is_public do %>
          <.input
            field={@form[:is_private]}
            type="checkbox"
            label="Make this a private event (only visible to group members)"
          />
        <% else %>
          <p class="text-sm text-gray-600">
            <.icon name="hero-lock-closed" class="h-4 w-4 inline" />
            This will be a private event (private groups can only create private events)
          </p>
        <% end %>

        <div class="flex gap-4">
          <.button type="submit" phx-disable-with="Creating...">
            Create Huddl
          </.button>
          <.link navigate={~p"/groups/#{@group.slug}"} class="btn btn-ghost">
            Cancel
          </.link>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    event_type = Map.get(params, "event_type", "in_person")

    # Update visibility based on event type
    socket =
      socket
      |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
      |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("event_type_changed", %{"form" => params}, socket) do
    event_type = params["event_type"]

    # Update visibility based on event type
    socket =
      socket
      |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
      |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])

    # Also run validation
    form =
      AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Set is_private to true for private groups
    params =
      if socket.assigns.group.is_public do
        params
      else
        Map.put(params, "is_private", "true")
      end

    # Add group_id and creator_id to params
    params =
      params
      |> Map.put("group_id", socket.assigns.group.id)
      |> Map.put("creator_id", socket.assigns.current_user.id)

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, _huddl} ->
        {:noreply,
         socket
         |> put_flash(:info, "Huddl created successfully!")
         |> redirect(to: ~p"/groups/#{socket.assigns.group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp check_can_create_huddl(group, user) do
    # For now, just check if user is owner or organizer
    # Access control will be properly implemented in task 3
    cond do
      owner?(group, user) -> :ok
      organizer?(group, user) -> :ok
      true -> {:error, :not_authorized}
    end
  end

  defp owner?(group, user) do
    group.owner_id == user.id
  end

  defp organizer?(group, user) do
    Huddlz.Communities.GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id and role == :organizer)
    |> Ash.exists?(authorize?: false)
  end
end
