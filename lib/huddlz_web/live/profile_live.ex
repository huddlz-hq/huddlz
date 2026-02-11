defmodule HuddlzWeb.ProfileLive do
  @moduledoc """
  LiveView for viewing and editing user profile settings.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Storage.ProfilePictures
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    form =
      user
      |> AshPhoenix.Form.for_update(:update_display_name,
        domain: Huddlz.Accounts,
        forms: [auto?: true],
        actor: user
      )
      |> to_form()

    action =
      if user.hashed_password, do: :change_password, else: :set_password

    password_form =
      user
      |> AshPhoenix.Form.for_update(action,
        domain: Huddlz.Accounts,
        forms: [auto?: true],
        actor: user
      )
      |> to_form()

    location_form =
      user
      |> AshPhoenix.Form.for_update(:update_home_location,
        domain: Huddlz.Accounts,
        forms: [auto?: true],
        actor: user
      )
      |> to_form()

    # Load user with profile picture calculation
    {:ok, user_with_avatar} =
      Ash.load(
        user,
        [:current_profile_picture_url, :home_location, :home_latitude, :home_longitude],
        actor: user
      )

    {:ok,
     socket
     |> assign(:page_title, "Profile")
     |> assign(:form, form)
     |> assign(:password_form, password_form)
     |> assign(:location_form, location_form)
     |> assign(:current_user, user_with_avatar)
     |> assign(:avatar_error, nil)
     |> assign(:location_error, nil)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_upload_progress/3
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Profile Settings
        <:subtitle>Manage your profile information</:subtitle>
      </.header>

      <div class="mt-8">
        <h2 class="font-display text-lg tracking-tight text-glow">Profile Picture</h2>
        <p class="text-base-content/50 mb-4">
          Upload a profile picture to personalize your account.
        </p>

        <div class="relative inline-block">
          <div class="relative">
            <.avatar user={@current_user} size={:xl} />
            <button
              type="button"
              phx-click={JS.toggle(to: "#avatar-menu")}
              class="absolute bottom-0 right-0 w-6 h-6 flex items-center justify-center bg-base-200 border border-base-300 text-primary cursor-pointer"
            >
              <.icon name="hero-pencil" class="w-3 h-3" />
            </button>
          </div>

          <div
            id="avatar-menu"
            class="hidden absolute left-0 mt-2 w-48 border border-base-300 bg-base-200 z-10"
            phx-click-away={JS.hide(to: "#avatar-menu")}
          >
            <label
              for={@uploads.avatar.ref}
              class="block w-full text-left px-4 py-2 text-sm hover:text-primary cursor-pointer transition-colors"
              phx-click={JS.hide(to: "#avatar-menu")}
            >
              Upload a photo...
            </label>
            <%= if @current_user.current_profile_picture_url do %>
              <button
                type="button"
                phx-click="remove_avatar"
                data-confirm="Are you sure you want to remove your profile picture?"
                class="block w-full text-left px-4 py-2 text-sm text-error hover:text-error/70 transition-colors"
              >
                <span>Remove</span>
              </button>
            <% end %>
          </div>

          <form id="avatar-form" phx-change="validate_avatar" class="hidden">
            <.live_file_input upload={@uploads.avatar} />
          </form>
        </div>

        <%= if @avatar_error do %>
          <p class="text-error text-sm mt-2">{@avatar_error}</p>
        <% end %>

        <div class="mt-10">
          <h2 class="font-display text-lg tracking-tight text-glow">Account Information</h2>
          <div class="mt-4 space-y-3">
            <div class="flex items-center gap-3">
              <span class="w-16 mono-label text-primary/70">Email</span>
              <span class="text-base-content/50">{@current_user.email}</span>
            </div>
            <div class="flex items-center gap-3">
              <span class="w-16 mono-label text-primary/70">Role</span>
              <span class={[
                "text-xs px-2.5 py-1 font-medium",
                @current_user.role == :admin && "bg-primary/10 text-primary",
                @current_user.role == :user && "bg-base-300 text-base-content/50"
              ]}>
                {@current_user.role |> to_string() |> String.capitalize()}
              </span>
            </div>
          </div>
        </div>

        <div class="mt-10">
          <h2 class="font-display text-lg tracking-tight text-glow">Display Name</h2>
          <p class="text-base-content/50 mb-4">
            This is how other users will see you on the platform.
          </p>

          <form phx-submit="save" phx-change="validate">
            <.input
              field={@form[:display_name]}
              type="text"
              label="Display Name"
              placeholder="Enter your display name"
            />

            <div class="mt-4">
              <.button type="submit">
                Save Changes
              </.button>
            </div>
          </form>
        </div>

        <div class="mt-10">
          <h2 class="font-display text-lg tracking-tight text-glow">Home Location</h2>
          <p class="text-base-content/50 mb-4">
            Set your home city to pre-fill location search when browsing huddlz.
          </p>

          <form phx-submit="save_location" phx-change="validate_location">
            <div class="flex items-end gap-3">
              <div class="flex-1">
                <.input
                  field={@location_form[:home_location]}
                  type="text"
                  label="City / Region"
                  placeholder="e.g. Austin, TX"
                />
              </div>
              <%= if @current_user.home_location do %>
                <button
                  type="button"
                  phx-click="clear_location"
                  class="mb-1 text-sm text-base-content/50 hover:text-error transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              <% end %>
            </div>

            <%= if @location_error do %>
              <p class="text-error text-sm mt-2">{@location_error}</p>
            <% end %>

            <div class="mt-4">
              <.button type="submit">
                Save Location
              </.button>
            </div>
          </form>
        </div>

        <div class="mt-10">
          <h2 class="font-display text-lg tracking-tight text-glow">
            {if @current_user.hashed_password, do: "Change", else: "Set"} Password
          </h2>
          <p class="text-base-content/50 mb-4">
            <%= if @current_user.hashed_password do %>
              Update your password to keep your account secure.
            <% else %>
              Set a password to enable password-based sign in.
            <% end %>
          </p>

          <form id="password-form" phx-submit="update_password" phx-change="validate_password">
            <%= if @current_user.hashed_password do %>
              <.input
                field={@password_form[:current_password]}
                type="password"
                label="Current Password"
                placeholder="Enter your current password"
                autocomplete="current-password"
              />
            <% end %>

            <.input
              field={@password_form[:password]}
              type="password"
              label="New Password"
              placeholder="Enter your new password"
              autocomplete="new-password"
            />

            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm New Password"
              placeholder="Confirm your new password"
              autocomplete="new-password"
            />

            <div class="mt-4">
              <.button type="submit">
                {if @current_user.hashed_password, do: "Update", else: "Set"} Password
              </.button>
            </div>
          </form>
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
  def handle_event("validate_location", %{"form" => params}, socket) do
    form =
      socket.assigns.location_form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, socket |> assign(:location_form, form) |> assign(:location_error, nil)}
  end

  @impl true
  def handle_event("save_location", %{"form" => params}, socket) do
    location_text = params["home_location"]

    case geocode_for_profile(location_text) do
      {:ok, lat, lng} ->
        submit_params = Map.merge(params, %{"home_latitude" => lat, "home_longitude" => lng})
        save_location_form(socket, submit_params)

      {:error, :not_found} ->
        {:noreply, assign(socket, :location_error, "Could not find that location. Try a more specific address.")}

      {:error, _reason} ->
        {:noreply, assign(socket, :location_error, "Location search is currently unavailable. Please try again later.")}
    end
  end

  @impl true
  def handle_event("clear_location", _params, socket) do
    user = socket.assigns.current_user

    case Huddlz.Accounts.update_home_location(user, nil, nil, nil, actor: user) do
      {:ok, updated_user} ->
        location_form =
          updated_user
          |> AshPhoenix.Form.for_update(:update_home_location,
            domain: Huddlz.Accounts,
            forms: [auto?: true],
            actor: updated_user
          )
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Home location cleared")
         |> assign(:current_user, updated_user)
         |> assign(:location_form, location_form)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to clear location")}
    end
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
         |> assign(:password_form, password_form)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update password. Please check the errors below.")
         |> assign(:password_form, form |> to_form())}
    end
  end

  @impl true
  def handle_event("validate_avatar", _params, socket) do
    {:noreply, assign(socket, :avatar_error, nil)}
  end

  @impl true
  def handle_event("remove_avatar", _params, socket) do
    user = socket.assigns.current_user

    # Soft-delete all profile pictures for the user
    case soft_delete_all_profile_pictures(user) do
      :ok ->
        # Reload user to clear the profile picture
        {:ok, updated_user} =
          Ash.load(user, [:current_profile_picture_url], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Profile picture removed")
         |> assign(:current_user, updated_user)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove profile picture")}
    end
  end

  defp geocode_for_profile(nil), do: {:error, :invalid_address}
  defp geocode_for_profile(""), do: {:error, :invalid_address}

  defp geocode_for_profile(location_text) do
    case Huddlz.Geocoding.geocode(location_text) do
      {:ok, %{latitude: lat, longitude: lng}} -> {:ok, lat, lng}
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_location_form(socket, submit_params) do
    case AshPhoenix.Form.submit(socket.assigns.location_form.source, params: submit_params) do
      {:ok, updated_user} ->
        location_form =
          updated_user
          |> AshPhoenix.Form.for_update(:update_home_location,
            domain: Huddlz.Accounts,
            forms: [auto?: true],
            actor: updated_user
          )
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Home location updated")
         |> assign(:current_user, updated_user)
         |> assign(:location_form, location_form)}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update location")
         |> assign(:location_form, form |> to_form())}
    end
  end

  defp soft_delete_all_profile_pictures(user) do
    case Huddlz.Accounts.list_profile_pictures(user.id, actor: user) do
      {:ok, pictures} ->
        Enum.each(pictures, fn picture ->
          Huddlz.Accounts.soft_delete_profile_picture(picture, actor: user)
        end)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_upload_progress(:avatar, entry, socket) do
    if entry.done? do
      process_auto_upload(socket)
    else
      {:noreply, socket}
    end
  end

  defp process_auto_upload(socket) do
    user = socket.assigns.current_user

    result =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, e ->
        case ProfilePictures.store(path, e.client_name, e.client_type, user.id) do
          {:ok, metadata} -> {:ok, {:success, metadata, e}}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    handle_upload_result(socket, user, result)
  end

  defp handle_upload_result(socket, user, [{:success, metadata, e}]) do
    soft_delete_all_profile_pictures(user)

    case create_profile_picture_record(user, %{
           filename: e.client_name,
           content_type: e.client_type,
           size_bytes: metadata.size_bytes,
           storage_path: metadata.storage_path,
           thumbnail_path: metadata.thumbnail_path
         }) do
      {:ok, _} ->
        {:noreply, reload_user_avatar(socket, user, "Profile picture updated successfully")}

      {:error, _} ->
        {:noreply,
         assign(socket, :avatar_error, "Failed to save profile picture. Please try again.")}
    end
  end

  defp handle_upload_result(socket, _user, [{:error, reason}]) do
    {:noreply, assign(socket, :avatar_error, "Upload failed: #{reason}")}
  end

  defp handle_upload_result(socket, _user, []) do
    {:noreply, socket}
  end

  defp create_profile_picture_record(user, metadata) do
    Huddlz.Accounts.create_profile_picture(
      %{
        filename: metadata.filename,
        content_type: metadata.content_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path,
        user_id: user.id
      },
      actor: user
    )
  end

  defp reload_user_avatar(socket, user, flash_message) do
    {:ok, updated_user} = Ash.load(user, [:current_profile_picture_url], actor: user)

    socket
    |> put_flash(:info, flash_message)
    |> assign(:current_user, updated_user)
  end
end
