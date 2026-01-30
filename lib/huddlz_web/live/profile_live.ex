defmodule HuddlzWeb.ProfileLive do
  @moduledoc """
  LiveView for viewing and editing user profile settings.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Storage.ProfilePictures
  alias HuddlzWeb.Components.AddressInputLive
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

    # Load user with profile picture calculation
    {:ok, user_with_avatar} =
      Ash.load(user, [:current_profile_picture_url], actor: user)

    # Load user's address if exists
    user_address =
      case Huddlz.Accounts.get_user_address(user.id, actor: user) do
        {:ok, address} -> address
        _ -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Profile")
     |> assign(:form, form)
     |> assign(:password_form, password_form)
     |> assign(:show_password_form, false)
     |> assign(:current_user, user_with_avatar)
     |> assign(:avatar_error, nil)
     |> assign(:user_address, user_address)
     |> assign(:address_data, if(user_address, do: address_to_map(user_address), else: nil))
     |> assign(:address_display, if(user_address, do: user_address.formatted_address, else: nil))
     |> assign(:editing_address, false)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  defp address_to_map(address) do
    %{
      formatted_address: address.formatted_address,
      latitude: address.latitude,
      longitude: address.longitude,
      street_number: address.street_number,
      street_name: address.street_name,
      city: address.city,
      state: address.state,
      postal_code: address.postal_code,
      country: address.country,
      country_name: address.country_name,
      place_id: address.place_id
    }
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
              <h2 class="card-title">Profile Picture</h2>
              <p class="text-base-content/70 mb-4">
                Upload a profile picture to personalize your account.
              </p>

              <div class="flex items-start gap-6">
                <div class="flex-shrink-0">
                  <.avatar user={@current_user} size={:xl} />
                </div>

                <div class="flex-1 space-y-4">
                  <form id="avatar-form" phx-submit="save_avatar" phx-change="validate_avatar">
                    <div
                      class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center hover:border-primary transition-colors"
                      phx-drop-target={@uploads.avatar.ref}
                    >
                      <.live_file_input upload={@uploads.avatar} class="hidden" />
                      <label
                        for={@uploads.avatar.ref}
                        class="cursor-pointer flex flex-col items-center"
                      >
                        <.icon name="hero-cloud-arrow-up" class="w-8 h-8 text-base-content/50 mb-2" />
                        <span class="text-sm text-base-content/70">
                          Click to upload or drag and drop
                        </span>
                        <span class="text-xs text-base-content/50 mt-1">
                          JPG, PNG, or WebP (max 5MB)
                        </span>
                      </label>
                    </div>

                    <%= if @avatar_error do %>
                      <p class="text-error text-sm mt-2">{@avatar_error}</p>
                    <% end %>

                    <%= for entry <- @uploads.avatar.entries do %>
                      <div class="mt-3 flex items-center gap-3 p-3 bg-base-200 rounded-lg">
                        <.live_img_preview entry={entry} class="w-12 h-12 rounded-full object-cover" />
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium truncate">{entry.client_name}</p>
                          <div class="w-full bg-base-300 rounded-full h-1.5 mt-1">
                            <div
                              class="bg-primary h-1.5 rounded-full transition-all"
                              style={"width: #{entry.progress}%"}
                            >
                            </div>
                          </div>
                        </div>
                        <button
                          type="button"
                          phx-click="cancel_avatar_upload"
                          phx-value-ref={entry.ref}
                          class="btn btn-ghost btn-sm btn-circle"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </div>

                      <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                        <p class="text-error text-sm mt-1">{upload_error_to_string(err)}</p>
                      <% end %>
                    <% end %>

                    <%= for err <- upload_errors(@uploads.avatar) do %>
                      <p class="text-error text-sm mt-2">{upload_error_to_string(err)}</p>
                    <% end %>

                    <div class="flex gap-2 mt-4">
                      <%= if @uploads.avatar.entries != [] do %>
                        <button type="submit" class="btn btn-primary btn-sm">
                          <.icon name="hero-check" class="w-4 h-4 mr-1" /> Save
                        </button>
                      <% end %>

                      <%= if @current_user.current_profile_picture_url do %>
                        <button
                          type="button"
                          phx-click="remove_avatar"
                          class="btn btn-ghost btn-sm text-error"
                          data-confirm="Are you sure you want to remove your profile picture?"
                        >
                          <.icon name="hero-trash" class="w-4 h-4 mr-1" /> Remove
                        </button>
                      <% end %>
                    </div>
                  </form>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 card bg-base-100 shadow-xl">
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
                      @current_user.role == :user && "badge-neutral"
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

          <%!-- Location Card --%>
          <div class="mt-6 card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Location</h2>
              <p class="text-base-content/70 mb-4">
                Your location helps find nearby huddlz and connect with local groups.
              </p>

              <%= if @user_address && !@editing_address do %>
                <%!-- Display current address --%>
                <div class="flex items-start justify-between gap-4">
                  <div class="flex items-start gap-3">
                    <.icon name="hero-map-pin" class="h-5 w-5 text-primary mt-0.5" />
                    <div>
                      <p class="font-medium">{@user_address.formatted_address}</p>
                      <%= if @user_address.city && @user_address.state do %>
                        <p class="text-sm text-base-content/70">
                          {@user_address.city}, {@user_address.state}
                        </p>
                      <% end %>
                    </div>
                  </div>
                  <div class="flex gap-2">
                    <button type="button" phx-click="edit_address" class="btn btn-ghost btn-sm">
                      <.icon name="hero-pencil" class="h-4 w-4" /> Edit
                    </button>
                    <button
                      type="button"
                      phx-click="remove_address"
                      class="btn btn-ghost btn-sm text-error"
                      data-confirm="Are you sure you want to remove your location?"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </button>
                  </div>
                </div>
              <% else %>
                <%!-- Address input form --%>
                <.live_component
                  module={AddressInputLive}
                  id="profile-address"
                  label="Your Address"
                  value={@address_display}
                  on_select={fn address -> send(self(), {:address_selected, address}) end}
                  on_clear={fn -> send(self(), :address_cleared) end}
                />

                <%= if @address_data do %>
                  <div class="flex items-center gap-2 text-sm text-success mt-2">
                    <.icon name="hero-check-circle" class="h-4 w-4" /> Location updated
                  </div>
                <% end %>

                <div class="card-actions justify-end mt-4">
                  <%= if @editing_address && @user_address do %>
                    <button type="button" phx-click="cancel_edit_address" class="btn btn-ghost">
                      Cancel
                    </button>
                  <% end %>
                  <button
                    type="button"
                    phx-click="save_address"
                    class="btn btn-primary"
                    disabled={@address_data == nil}
                  >
                    {if @user_address, do: "Update", else: "Save"} Location
                  </button>
                </div>
              <% end %>
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
                      {if @current_user.hashed_password, do: "Update", else: "Set"} Password
                    </button>
                  </div>
                </form>
              <% else %>
                <button class="btn btn-primary" phx-click="show_password_form">
                  {if @current_user.hashed_password, do: "Change", else: "Set"} Password
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

  # Address event handlers
  @impl true
  def handle_event("edit_address", _params, socket) do
    {:noreply, assign(socket, editing_address: true)}
  end

  @impl true
  def handle_event("cancel_edit_address", _params, socket) do
    address = socket.assigns.user_address

    {:noreply,
     socket
     |> assign(editing_address: false)
     |> assign(address_display: if(address, do: address.formatted_address, else: nil))
     |> assign(address_data: if(address, do: address_to_map(address), else: nil))}
  end

  @impl true
  def handle_event("save_address", _params, socket) do
    user = socket.assigns.current_user
    address_data = socket.assigns.address_data

    attrs = %{
      formatted_address: address_data.formatted_address,
      latitude: address_data.latitude,
      longitude: address_data.longitude,
      street_number: address_data[:street_number],
      street_name: address_data[:street_name],
      city: address_data[:city],
      state: address_data[:state],
      postal_code: address_data[:postal_code],
      country: address_data[:country],
      country_name: address_data[:country_name],
      place_id: address_data[:place_id]
    }

    result =
      case socket.assigns.user_address do
        nil ->
          Huddlz.Accounts.create_user_address(Map.put(attrs, :user_id, user.id), actor: user)

        existing ->
          Huddlz.Accounts.update_user_address(existing, attrs, actor: user)
      end

    case result do
      {:ok, address} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location saved successfully")
         |> assign(user_address: address)
         |> assign(editing_address: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save location")}
    end
  end

  @impl true
  def handle_event("remove_address", _params, socket) do
    user = socket.assigns.current_user

    case Huddlz.Accounts.delete_user_address(socket.assigns.user_address, actor: user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Location removed")
         |> assign(user_address: nil)
         |> assign(address_data: nil)
         |> assign(address_display: nil)
         |> assign(editing_address: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove location")}
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
         |> assign(:password_form, password_form)
         |> assign(:show_password_form, false)}

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
  def handle_event("cancel_avatar_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl true
  def handle_event("save_avatar", _params, socket) do
    user = socket.assigns.current_user

    case uploaded_entries(socket, :avatar) do
      {[_ | _], []} ->
        process_avatar_upload(socket, user)

      {[], _} ->
        {:noreply, assign(socket, :avatar_error, "Please select a file to upload")}
    end
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

  # Handle geocoding messages from AddressInputLive component
  @impl true
  def handle_info({:do_search, component_id, query}, socket) do
    result = Huddlz.Geocoding.autocomplete(query)
    socket = AddressInputLive.handle_search_results(socket, component_id, result)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:do_place_details, component_id, place_id}, socket) do
    result = Huddlz.Geocoding.place_details(place_id)
    socket = AddressInputLive.handle_place_details(socket, component_id, result)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:address_selected, address_data}, socket) do
    {:noreply,
     socket
     |> assign(address_data: address_data)
     |> assign(address_display: address_data.formatted_address)}
  end

  @impl true
  def handle_info(:address_cleared, socket) do
    {:noreply,
     socket
     |> assign(address_data: nil)
     |> assign(address_display: nil)}
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

  defp process_avatar_upload(socket, user) do
    result =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        store_avatar_file(path, entry, user.id)
      end)

    handle_upload_result(socket, user, result)
  end

  defp store_avatar_file(path, entry, user_id) do
    case ProfilePictures.store(path, entry.client_name, entry.client_type, user_id) do
      {:ok, %{storage_path: storage_path, thumbnail_path: thumbnail_path, size_bytes: size_bytes}} ->
        {:ok,
         {:success,
          %{
            storage_path: storage_path,
            thumbnail_path: thumbnail_path,
            filename: entry.client_name,
            content_type: entry.client_type,
            size_bytes: size_bytes
          }}}

      {:error, reason} ->
        # Always return {:ok, _} from consume callback, wrap errors for handling
        {:ok, {:error, reason}}
    end
  end

  defp handle_upload_result(socket, user, [{:success, metadata}]) do
    # Soft-delete existing pictures before creating new one
    soft_delete_all_profile_pictures(user)

    case create_profile_picture_record(user, metadata) do
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

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"

  defp upload_error_to_string(:not_accepted),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  defp upload_error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
