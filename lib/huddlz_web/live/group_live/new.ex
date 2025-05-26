defmodule HuddlzWeb.GroupLive.New do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    # Check if user can create groups
    if can_create_group?(socket.assigns.current_user) do
      # Create a new changeset for the form
      form =
        AshPhoenix.Form.for_create(Group, :create_group,
          actor: socket.assigns.current_user,
          forms: [auto?: true]
        )

      {:ok,
       socket
       |> assign(:form, to_form(form))
       |> assign(:page_title, "New Group")}
    else
      {:ok,
       socket
       |> put_flash(:error, "You need to be a verified user to create groups")
       |> redirect(to: ~p"/groups")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)

    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save", params, socket) do
    # Extract form params, handling both wrapped and unwrapped formats
    form_params = Map.get(params, "form", params)

    # Add the current user as the owner
    params_with_owner = Map.put(form_params, "owner_id", socket.assigns.current_user.id)

    case socket.assigns.form.source
         |> AshPhoenix.Form.validate(params_with_owner)
         |> AshPhoenix.Form.submit(params: params_with_owner, actor: socket.assigns.current_user) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully")
         |> redirect(to: ~p"/groups/#{group.id}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Create a New Group
        <:subtitle>Create a group to organize huddlz and connect with others</:subtitle>
      </.header>

      <form id="group-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Group Name" required />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:location]} type="text" label="Location" />
        <.input field={@form[:image_url]} type="text" label="Image URL" />

        <div>
          <label class="block text-sm font-medium mb-2">Privacy</label>
          <div class="mt-2 space-y-2">
            <label class="flex items-center gap-3">
              <input type="hidden" name={@form[:is_public].name} value="false" />
              <input
                type="checkbox"
                name={@form[:is_public].name}
                id={@form[:is_public].id}
                value="true"
                checked={AshPhoenix.Form.value(@form.source, :is_public) == true}
                class="checkbox"
              />
              <span>Public group (visible to everyone)</span>
            </label>
            <p class="text-sm text-gray-500">
              Public groups are visible to all users. Private groups are only visible to members.
            </p>
          </div>
        </div>

        <div class="flex gap-4">
          <.button type="submit" phx-disable-with="Creating...">Create Group</.button>
          <.link navigate={~p"/groups"} class="btn btn-ghost">Cancel</.link>
        </div>
      </form>
    </Layouts.app>
    """
  end

  defp can_create_group?(nil), do: false

  defp can_create_group?(user) do
    user.role in [:admin, :verified]
  end
end
