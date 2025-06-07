defmodule HuddlzWeb.ProfileLive do
  use HuddlzWeb, :live_view

  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    form =
      socket.assigns.current_user
      |> AshPhoenix.Form.for_update(:update_display_name,
        domain: Huddlz.Accounts,
        forms: [auto?: true],
        actor: socket.assigns.current_user
      )
      |> to_form()

    action =
      if socket.assigns.current_user.hashed_password, do: :change_password, else: :set_password

    password_form =
      socket.assigns.current_user
      |> AshPhoenix.Form.for_update(action,
        domain: Huddlz.Accounts,
        forms: [auto?: true],
        actor: socket.assigns.current_user
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Profile")
     |> assign(:form, form)
     |> assign(:password_form, password_form)
     |> assign(:show_password_form, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-2xl mx-auto">
        <.header>
          Profile Settings
          <:subtitle>Manage your profile information</:subtitle>
        </.header>

        <div class="mt-8">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Account Information</h2>
              <div class="space-y-3">
                <div>
                  <span class="font-semibold">Email:</span>
                  <span class="ml-2 text-base-content/70">{@current_user.email}</span>
                </div>
                <div>
                  <span class="font-semibold">Role:</span>
                  <span class="ml-2">
                    <span class={[
                      "badge",
                      @current_user.role == :admin && "badge-primary",
                      @current_user.role == :verified && "badge-success",
                      @current_user.role == :regular && "badge-neutral"
                    ]}>
                      {@current_user.role |> to_string() |> String.capitalize()}
                    </span>
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Display Name</h2>
              <p class="text-base-content/70 mb-4">
                This is how other users will see you on the platform.
              </p>

              <form phx-submit="save" phx-change="validate">
                <.input
                  field={@form[:display_name]}
                  type="text"
                  label="Display Name"
                  placeholder="Enter your display name"
                  required
                />

                <div class="card-actions justify-end mt-6">
                  <button type="submit" class="btn btn-primary">
                    Save Changes
                  </button>
                </div>
              </form>
            </div>
          </div>

          <div class="mt-6 card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Preferences</h2>
              <div class="space-y-4">
                <div>
                  <h3 class="font-semibold mb-2">Theme</h3>
                  <p class="text-sm text-base-content/70 mb-3">
                    Choose your preferred color scheme
                  </p>
                  <Layouts.theme_toggle />
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">
                {if @current_user.hashed_password, do: "Change", else: "Set"} Password
              </h2>
              <p class="text-base-content/70 mb-4">
                <%= if @current_user.hashed_password do %>
                  Update your password to keep your account secure.
                <% else %>
                  Set a password to enable password-based sign in.
                <% end %>
              </p>

              <%= if @show_password_form do %>
                <form id="password-form" phx-submit="update_password" phx-change="validate_password">
                  <%= if @current_user.hashed_password do %>
                    <.input
                      field={@password_form[:current_password]}
                      type="password"
                      label="Current Password"
                      placeholder="Enter your current password"
                      required
                    />
                  <% end %>

                  <.input
                    field={@password_form[:password]}
                    type="password"
                    label="New Password"
                    placeholder="Enter your new password"
                    required
                  />

                  <.input
                    field={@password_form[:password_confirmation]}
                    type="password"
                    label="Confirm New Password"
                    placeholder="Confirm your new password"
                    required
                  />

                  <div class="card-actions justify-end mt-6 gap-2">
                    <button type="button" class="btn btn-ghost" phx-click="cancel_password">
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-primary">
                      {if @current_user.hashed_password, do: "Update Password", else: "Set Password"}
                    </button>
                  </div>
                </form>
              <% else %>
                <button class="btn btn-primary" phx-click="show_password_form">
                  {if @current_user.hashed_password, do: "Change Password", else: "Set Password"}
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, updated_user} ->
        form =
          updated_user
          |> AshPhoenix.Form.for_update(:update_display_name,
            domain: Huddlz.Accounts,
            forms: [auto?: true],
            actor: updated_user
          )
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Display name updated successfully")
         |> assign(:current_user, updated_user)
         |> assign(:form, form)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update display name. Please check the errors below.")
         |> assign(:form, form |> to_form())}
    end
  end

  @impl true
  def handle_event("show_password_form", _params, socket) do
    {:noreply, assign(socket, :show_password_form, true)}
  end

  @impl true
  def handle_event("cancel_password", _params, socket) do
    action =
      if socket.assigns.current_user.hashed_password, do: :change_password, else: :set_password

    password_form =
      socket.assigns.current_user
      |> AshPhoenix.Form.for_update(action,
        domain: Huddlz.Accounts,
        forms: [auto?: true],
        actor: socket.assigns.current_user
      )
      |> to_form()

    {:noreply,
     socket
     |> assign(:show_password_form, false)
     |> assign(:password_form, password_form)}
  end

  @impl true
  def handle_event("validate_password", %{"form" => params}, socket) do
    form =
      socket.assigns.password_form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :password_form, form)}
  end

  @impl true
  def handle_event("update_password", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.password_form.source, params: params) do
      {:ok, updated_user} ->
        action = if updated_user.hashed_password, do: :change_password, else: :set_password

        password_form =
          updated_user
          |> AshPhoenix.Form.for_update(action,
            domain: Huddlz.Accounts,
            forms: [auto?: true],
            actor: updated_user
          )
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully")
         |> assign(:current_user, updated_user)
         |> assign(:password_form, password_form)
         |> assign(:show_password_form, false)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update password. Please check the errors below.")
         |> assign(:password_form, form |> to_form())}
    end
  end
end
