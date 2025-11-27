defmodule HuddlzWeb.HuddlLive.Edit do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    case get_huddl(id, group_slug, socket.assigns.current_user) do
      {:ok, huddl} ->
        form =
          AshPhoenix.Form.for_update(huddl, :update,
            domain: Huddlz.Communities,
            actor: socket.assigns.current_user,
            forms: [auto?: true]
          )

        form =
          if huddl.huddl_template_id do
            AshPhoenix.Form.validate(form, %{
              is_recurring: true,
              repeat_until: huddl.huddl_template.repeat_until,
              frequency: huddl.huddl_template.frequency
            })
          else
            form
          end

        {:noreply,
         socket
         |> assign(:page_title, huddl.title)
         |> assign(:group_slug, group_slug)
         |> assign(:huddl, huddl)
         |> assign(:show_physical_location, !!huddl.physical_location)
         |> assign(:show_virtual_link, !!huddl.virtual_link)
         |> assign(:form, to_form(form))}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Huddl not found")
         |> redirect(to: ~p"/groups/#{group_slug}")}

      {:error, :not_authorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to edit this huddl")
         |> redirect(to: ~p"/groups/#{group_slug}/huddlz/#{id}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@group_slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@huddl.group.name}
      </.link>
      <.header>
        Editing {@huddl.title}
      </.header>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:starts_at]} type="datetime-local" label="Start Date & Time" required />
          <.input field={@form[:ends_at]} type="datetime-local" label="End Date & Time" required />
        </div>

        <%= if @huddl.huddl_template_id do %>
          <p>This is a recurring huddl. Please select which huddlz to update</p>
          <div class="form-control">
            <div>
              <input
                id="form_edit_type_instance"
                type="radio"
                name="form[edit_type]"
                class="radio"
                value="instance"
                checked={AshPhoenix.Form.value(@form.source, :edit_type) == "instance"}
              />
              <label class="label cursor-pointer" for="form_edit_type_instance">
                This huddl only
              </label>
            </div>
            <div>
              <input
                id="form_edit_type_all"
                type="radio"
                name="form[edit_type]"
                class="radio"
                value="all"
                checked={AshPhoenix.Form.value(@form.source, :edit_type) == "all"}
              />
              <label class="label cursor-pointer" for="form_edit_type_all">
                This and future huddlz in series
              </label>
            </div>
          </div>

          <div class={"grid gap-4 sm:grid-cols-2 #{@form[:edit_type].value == "instance" && "hidden"}"}>
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

        <%= if @huddl.group.is_public do %>
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
            Save Huddl
          </.button>
          <.link navigate={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}"} class="btn btn-ghost">
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

    form =
      AshPhoenix.Form.update_params(socket.assigns.form, &Map.merge(&1, params))

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Set is_private to true for private groups
    params =
      if socket.assigns.huddl.group.is_public do
        params
      else
        Map.put(params, "is_private", "true")
      end

    params =
      case params["event_type"] do
        "virtual" -> Map.put(params, "physical_location", nil)
        "in_person" -> Map.put(params, "virtual_link", nil)
        _ -> params
      end

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, _huddl} ->
        {:noreply,
         socket
         |> put_flash(:info, "Huddl updated successfully!")
         |> redirect(
           to: ~p"/groups/#{socket.assigns.huddl.group.slug}/huddlz/#{socket.assigns.huddl.id}"
         )}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp get_huddl(id, group_slug, user) do
    # Get the huddl and verify it belongs to the group with the given slug
    case Huddl
         |> Ash.Query.filter(id == ^id)
         |> Ash.Query.load([
           :creator,
           :group,
           :huddl_template,
           :status,
           :visible_virtual_link
         ])
         |> Ash.read_one(actor: user) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, huddl} ->
        verify_group_and_ownership(huddl, user, group_slug)

      {:error, _} ->
        {:error, :not_authorized}
    end
  end

  defp verify_group_and_ownership(huddl, user, group_slug) do
    if huddl.group.slug == group_slug && huddl.creator_id == user.id do
      {:ok, huddl}
    else
      if huddl.group.slug != group_slug do
        {:error, :not_found}
      else
        {:error, :not_authorized}
      end
    end
  end
end
