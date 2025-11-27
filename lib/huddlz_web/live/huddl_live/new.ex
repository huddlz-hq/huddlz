defmodule HuddlzWeb.HuddlLive.New do
  @moduledoc """
  LiveView for creating a new huddl within a group.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"group_slug" => group_slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(group_slug, user),
         :ok <- authorize({Huddl, :create, %{group_id: group.id}}, user) do
      {:ok, assign_create_form(socket, group, user)}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         handle_error(socket, :not_authorized,
           message: "You don't have permission to create huddlz for this group",
           resource_path: ~p"/groups/#{group_slug}"
         )}
    end
  end

  defp assign_create_form(socket, group, user) do
    tomorrow = Date.utc_today() |> Date.add(1)
    default_time = ~T[14:00:00]

    form =
      AshPhoenix.Form.for_create(Huddl, :create,
        domain: Huddlz.Communities,
        actor: user,
        params: %{
          "group_id" => group.id,
          "creator_id" => user.id,
          "date" => Date.to_iso8601(tomorrow),
          "start_time" => Time.to_iso8601(default_time) |> String.slice(0..4),
          "duration_minutes" => "60"
        }
      )

    socket
    |> assign(:page_title, "Create New Huddl")
    |> assign(:group, group)
    |> assign(:form, to_form(form))
    |> assign(:show_virtual_link, false)
    |> assign(:show_physical_location, true)
    |> assign(:calculated_end_time, calculate_end_time(tomorrow, default_time, 60))
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
          <.date_picker field={@form[:date]} label="Date" />
          <.time_picker field={@form[:start_time]} label="Start Time" />
        </div>

        <.duration_picker field={@form[:duration_minutes]} label="Duration" />

        <%= if @calculated_end_time do %>
          <div class="alert alert-info">
            <.icon name="hero-clock" class="h-5 w-5" />
            <span>Ends at: {@calculated_end_time}</span>
          </div>
        <% end %>

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
          <p class="text-sm text-base-content/80">
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

    # Calculate end time if we have date, time, and duration
    socket =
      case {params["date"], params["start_time"], params["duration_minutes"]} do
        {date_str, time_str, duration_str}
        when date_str != "" and time_str != "" and duration_str != "" ->
          with {:ok, date} <- Date.from_iso8601(date_str),
               {:ok, time} <- parse_time(time_str),
               {duration, ""} <- Integer.parse(duration_str) do
            assign(socket, :calculated_end_time, calculate_end_time(date, time, duration))
          else
            _ -> socket
          end

        _ ->
          socket
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, params)

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

  defp calculate_end_time(date, time, duration_minutes) do
    case DateTime.new(date, time, "Etc/UTC") do
      {:ok, starts_at} ->
        ends_at = DateTime.add(starts_at, duration_minutes, :minute)

        # Format the end time nicely
        if Date.compare(DateTime.to_date(ends_at), date) == :eq do
          # Same day
          Calendar.strftime(ends_at, "%I:%M %p")
        else
          # Next day
          Calendar.strftime(ends_at, "%I:%M %p (next day)")
        end

      _ ->
        nil
    end
  end

  defp parse_time(time_str) do
    # Parse time string in format HH:MM or HH:MM:SS
    case String.split(time_str, ":") do
      [hour_str, minute_str] ->
        with {hour, ""} <- Integer.parse(hour_str),
             {minute, ""} <- Integer.parse(minute_str) do
          Time.new(hour, minute, 0)
        end

      [hour_str, minute_str, _second_str] ->
        with {hour, ""} <- Integer.parse(hour_str),
             {minute, ""} <- Integer.parse(minute_str) do
          Time.new(hour, minute, 0)
        end

      _ ->
        :error
    end
  end
end
