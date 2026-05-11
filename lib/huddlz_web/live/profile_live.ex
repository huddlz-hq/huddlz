defmodule HuddlzWeb.ProfileLive do
  @moduledoc """
  LiveView for viewing and editing user profile settings.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Storage.ProfilePictures
  alias HuddlzWeb.Avatar
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

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
    <Layouts.v3_app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="profile"
    >
      <div class="page-head">
        <div>
          <h1>Profile</h1>
          <p>How you show up in huddlz — your name, photo, and how to reach you.</p>
        </div>
      </div>

      <div class="panel">
        <div class="panel-head">
          <h2>Profile picture</h2>
        </div>
        <div class="profile-photo-row">
          <.big_avatar user={@current_user} />
          <div class="profile-photo-actions">
            <label for={@uploads.avatar.ref} class="btn-secondary" style="cursor:pointer">
              Upload a photo…
            </label>
            <%= if @current_user.current_profile_picture_url do %>
              <button
                type="button"
                class="btn-secondary muted-btn"
                phx-click="remove_avatar"
                data-confirm="Are you sure you want to remove your profile picture?"
              >
                Remove
              </button>
            <% end %>
            <div class="muted" style="font-size:12px; margin-top:6px">
              JPG, PNG, or WebP · 5 MB max
            </div>
            <p :if={@avatar_error} class="form-error">{@avatar_error}</p>
          </div>
        </div>
        <form id="avatar-form" phx-change="validate_avatar" class="hidden">
          <.live_file_input upload={@uploads.avatar} />
        </form>
      </div>

      <.form for={@form} phx-submit="save" phx-change="validate">
        <div class="panel">
          <div class="panel-head">
            <h2>Account information</h2>
          </div>
          <div class="form-grid">
            <div class="form-row">
              <label class="form-label">Email</label>
              <div class="form-control read-only">
                <span>{@current_user.email}</span>
                <span class={["pill", role_pill_color(@current_user.role)]}>
                  {role_label(@current_user.role)}
                </span>
              </div>
              <p class="form-help">Your email can't be changed from this page.</p>
            </div>
            <.v3_input
              field={@form[:display_name]}
              label="Display name"
              placeholder="Enter your display name"
              help="Names aren't unique on huddlz — pick anything you like."
            />
          </div>
          <div class="form-foot">
            <.v3_button variant={:primary} type="submit">Save changes</.v3_button>
          </div>
        </div>
      </.form>

      <div class="panel">
        <div class="panel-head">
          <div>
            <h2>Home location</h2>
            <div class="panel-sub">
              Used to pre-fill the distance filter when you search huddlz nearby.
            </div>
          </div>
        </div>
        <form class="form-row">
          <.live_component
            module={HuddlzWeb.Live.LocationAutocomplete}
            id="profile-location"
            variant={:v3_form}
            field_name="home_location"
            value={@current_user.home_location}
            latitude={@current_user.home_latitude}
            longitude={@current_user.home_longitude}
            placeholder="e.g. Austin, TX"
          />
          <p :if={@location_error} class="form-error">{@location_error}</p>
        </form>
      </div>

      <.form
        for={@password_form}
        id="password-form"
        phx-submit="update_password"
        phx-change="validate_password"
      >
        <div class="panel">
          <div class="panel-head">
            <div>
              <h2>{if @current_user.hashed_password, do: "Change", else: "Set"} password</h2>
              <div class="panel-sub">
                <%= if @current_user.hashed_password do %>
                  Update your password to keep your account secure.
                <% else %>
                  Set a password to enable password-based sign in.
                <% end %>
              </div>
            </div>
          </div>
          <div class="form-grid">
            <%= if @current_user.hashed_password do %>
              <.v3_input
                field={@password_form[:current_password]}
                type="password"
                label="Current password"
                placeholder="Enter your current password"
                autocomplete="current-password"
              />
            <% end %>
            <.v3_input
              field={@password_form[:password]}
              type="password"
              label="New password"
              placeholder="Enter your new password"
              autocomplete="new-password"
              help="At least 8 characters."
            />
            <.v3_input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              placeholder="Confirm your new password"
              autocomplete="new-password"
            />
          </div>
          <div class="form-foot">
            <.v3_button variant={:primary} type="submit">
              {if @current_user.hashed_password, do: "Update", else: "Set"} password
            </.v3_button>
          </div>
        </div>
      </.form>
    </Layouts.v3_app>
    """
  end

  attr :user, :map, required: true

  defp big_avatar(assigns) do
    ~H"""
    <%= cond do %>
      <% url = Avatar.picture_url(@user) -> %>
        <img class="big-avatar" src={url} alt="" aria-hidden="true" />
      <% initials = Avatar.initials(@user) -> %>
        <div class="big-avatar">{initials}</div>
      <% true -> %>
        <div class="big-avatar"></div>
    <% end %>
    """
  end

  defp role_label(:admin), do: "Admin"
  defp role_label(role) when is_atom(role), do: role |> to_string() |> String.capitalize()
  defp role_label(_), do: "Member"

  defp role_pill_color(:admin), do: "magenta"
  defp role_pill_color(_), do: "cyan"

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

  @impl true
  def handle_info(
        {:location_selected, "profile-location",
         %{display_text: text, latitude: lat, longitude: lng}},
        socket
      ) do
    user = socket.assigns.current_user

    case Huddlz.Accounts.update_home_location(user, text, lat, lng, actor: user) do
      {:ok, updated_user} ->
        {:ok, updated_user} =
          Ash.load(updated_user, [:home_location, :home_latitude, :home_longitude], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Home location updated")
         |> assign(:current_user, updated_user)
         |> assign(:location_error, nil)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update location")}
    end
  end

  def handle_info({:location_cleared, "profile-location"}, socket) do
    user = socket.assigns.current_user

    case Huddlz.Accounts.update_home_location(user, nil, nil, nil, actor: user) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Home location cleared")
         |> assign(:current_user, updated_user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to clear location")}
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
