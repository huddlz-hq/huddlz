defmodule HuddlzWeb.ProfileLive do
  @moduledoc """
  LiveView for viewing and editing user profile settings.
  """
  use HuddlzWeb, :live_view

  require Logger

  alias Huddlz.Storage.ProfilePictures
  alias HuddlzWeb.AuthFormErrors
  alias HuddlzWeb.Avatar
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.UploadHelpers
  alias Phoenix.LiveView.JS

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

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

    email_form = email_form(user)

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
     |> assign(:email_form, email_form)
     |> assign(:password_form, password_form)
     |> assign(:password_input_reset_generation, 0)
     |> assign(:current_user, user_with_avatar)
     |> assign(:avatar_error, nil)
     |> assign(:remove_avatar_dialog_open, false)
     |> assign(:location_error, nil)
     |> assign(:pending_home_location, nil)
     |> assign(
       :home_location_time_zone_form,
       to_form(%{"time_zone" => ""}, as: :home_location_time_zone)
     )
     |> UploadHelpers.allow_image_upload(:avatar, &handle_upload_progress/3)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
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
                id="open-remove-avatar-dialog"
                type="button"
                class="btn-secondary muted-btn"
                phx-click={JS.push_focus() |> JS.push("open_remove_avatar_dialog")}
              >
                Remove
              </button>
            <% end %>
            <div class="muted" style="font-size:12px; margin-top:6px">
              <span id="avatar-upload-help">JPG, PNG, or WebP · 5 MB max</span>
            </div>
            <div id="avatar-upload-status" aria-live="polite">
              <%= for entry <- @uploads.avatar.entries,
                      upload_errors(@uploads.avatar, entry) == [] and entry.progress < 100 do %>
                <p class="muted" role="status">
                  Uploading {entry.client_name}: {entry.progress}%
                </p>
              <% end %>
            </div>
            <div
              :if={avatar_upload_error_messages(@uploads.avatar, @avatar_error) != []}
              id="avatar-upload-error"
              class="form-error"
              role="alert"
              aria-live="assertive"
            >
              <p :for={message <- avatar_upload_error_messages(@uploads.avatar, @avatar_error)}>
                {message}
              </p>
            </div>
          </div>
        </div>
        <form id="avatar-form" phx-change="validate_avatar" class="hidden">
          <.live_file_input
            upload={@uploads.avatar}
            aria-describedby="avatar-upload-help avatar-upload-error"
            aria-invalid={
              avatar_upload_error_messages(@uploads.avatar, @avatar_error) != [] && "true"
            }
          />
        </form>
      </div>

      <.form for={@form} id="profile-form" phx-submit="save" phx-change="validate">
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
              <p class="form-help">This is the email you use to sign in.</p>
            </div>
            <.input
              field={@form[:display_name]}
              value={form_value(@form, :display_name)}
              label="Display name"
              placeholder="Enter your display name"
              help="Names aren't unique on huddlz — pick anything you like."
            />
          </div>
          <div class="form-foot">
            <.button variant={:primary} type="submit">Save changes</.button>
          </div>
        </div>
      </.form>

      <.form
        for={@email_form}
        id="email-change-form"
        phx-submit="change_email"
        phx-change="validate_email"
      >
        <div class="panel">
          <div class="panel-head">
            <div>
              <h2>Change email</h2>
              <div class="panel-sub">
                Update your sign-in email after confirming your current password.
              </div>
            </div>
          </div>
          <div class="form-grid">
            <.input
              field={@email_form[:email]}
              type="text"
              label="New email"
              placeholder="Enter your new email"
              autocomplete="email"
              inputmode="email"
            />
            <.input
              field={@email_form[:current_password]}
              type="password"
              label="Confirm current password"
              placeholder="Enter your current password"
              autocomplete="current-password"
            />
          </div>
          <div class="form-foot">
            <.button id="change-email-button" variant={:primary} type="submit">
              Change email
            </.button>
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
            variant={:form}
            field_name="home_location"
            value={@current_user.home_location}
            latitude={@current_user.home_latitude}
            longitude={@current_user.home_longitude}
            placeholder="e.g. Austin, TX"
          />
          <p :if={@location_error} class="form-error">{@location_error}</p>
        </form>
        <.form
          :if={@pending_home_location}
          for={@home_location_time_zone_form}
          id="home-location-time-zone-form"
          phx-submit="save_home_location_time_zone"
        >
          <p id="home-location-time-zone-error" class="form-error">
            Choose a valid time zone for this home location.
          </p>
          <.select
            field={@home_location_time_zone_form[:time_zone]}
            id="home-location-time-zone"
            label="Home location time zone"
            prompt="Choose a time zone"
            options={Tzdata.canonical_zone_list()}
          />
          <.button id="save-home-location-time-zone" variant={:primary} type="submit">
            Save home location
          </.button>
        </.form>
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
              <.input
                field={@password_form[:current_password]}
                id={"password-#{@password_input_reset_generation}-current-password"}
                value=""
                type="password"
                phx-update="ignore"
                label="Current password"
                placeholder="Enter your current password"
                autocomplete="current-password"
              />
            <% end %>
            <.input
              field={@password_form[:password]}
              id={"password-#{@password_input_reset_generation}-password"}
              value=""
              type="password"
              phx-update="ignore"
              label="New password"
              placeholder="Enter your new password"
              autocomplete="new-password"
              help="At least 8 characters."
            />
            <.input
              field={@password_form[:password_confirmation]}
              id={"password-#{@password_input_reset_generation}-password-confirmation"}
              value=""
              type="password"
              phx-update="ignore"
              label="Confirm new password"
              placeholder="Confirm your new password"
              autocomplete="new-password"
            />
          </div>
          <div class="form-foot">
            <.button variant={:primary} type="submit">
              {if @current_user.hashed_password, do: "Update", else: "Set"} password
            </.button>
          </div>
        </div>
      </.form>

      <.modal
        :if={@remove_avatar_dialog_open}
        id="remove-avatar-dialog"
        show
        on_cancel={JS.push("cancel_remove_avatar")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-user-circle" class="h-6 w-6" />
          </div>

          <div class="delete-confirm-copy">
            <span class="eyebrow eyebrow-magenta">Profile picture</span>
            <h2 id="remove-avatar-dialog-title">Remove your profile picture?</h2>
            <p>
              Your current picture will be removed. Your <strong>initials will appear instead</strong>
              everywhere your profile is shown.
            </p>
          </div>
        </div>

        <div class="delete-confirm-actions">
          <.button
            variant={:muted}
            id="cancel-remove-avatar"
            phx-click="cancel_remove_avatar"
          >
            Keep picture
          </.button>
          <.button
            variant={:destructive}
            class="delete-confirm-submit"
            id="confirm-remove-avatar"
            phx-click="remove_avatar"
            phx-disable-with="Removing…"
          >
            Remove picture
          </.button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  attr :user, :map, required: true

  defp big_avatar(assigns) do
    ~H"""
    <%= cond do %>
      <% url = Avatar.picture_url(@user) -> %>
        <img id="profile-avatar" class="big-avatar" src={url} alt="" aria-hidden="true" />
      <% initials = Avatar.initials(@user) -> %>
        <div id="profile-avatar" class="big-avatar">{initials}</div>
      <% true -> %>
        <div id="profile-avatar" class="big-avatar"></div>
    <% end %>
    """
  end

  defp role_label(:admin), do: "Admin"
  defp role_label(role) when is_atom(role), do: role |> to_string() |> String.capitalize()
  defp role_label(_), do: "Member"

  defp role_pill_color(:admin), do: "magenta"
  defp role_pill_color(_), do: "cyan"

  defp avatar_upload_error_messages(upload, avatar_error) do
    entry_errors =
      Enum.flat_map(upload.entries, fn entry ->
        upload
        |> upload_errors(entry)
        |> Enum.map(&UploadHelpers.upload_error_to_string/1)
      end)

    config_errors =
      upload
      |> upload_errors()
      |> Enum.map(&UploadHelpers.upload_error_to_string/1)

    [avatar_error | entry_errors ++ config_errors]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp form_value(form, field) do
    Map.get(form.source.raw_params, to_string(field), form[field].value)
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
  def handle_event("validate_email", %{"email_change" => params}, socket) do
    form =
      socket.assigns.email_form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :email_form, form)}
  end

  @impl true
  def handle_event("change_email", %{"email_change" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.email_form.source, params: params) do
      {:ok, updated_user} ->
        updated_user =
          Ash.load!(
            updated_user,
            [:current_profile_picture_url, :home_location, :home_latitude, :home_longitude],
            actor: updated_user
          )

        {:noreply,
         socket
         |> clear_flash(:error)
         |> put_flash(:info, "Email updated successfully")
         |> assign(:current_user, updated_user)
         |> assign(:email_form, email_form(updated_user))}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Email could not be updated. Please check the errors below.")
         |> assign(
           :email_form,
           form
           |> AshPhoenix.Form.clear_value(:current_password)
           |> to_form()
         )}
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
         |> update(:password_input_reset_generation, &(&1 + 1))}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update password. Please check the errors below.")
         |> assign(:password_form, form |> to_form())
         |> update(:password_input_reset_generation, &(&1 + 1))}
    end
  end

  @impl true
  def handle_event("validate_avatar", _params, socket) do
    {:noreply, clear_avatar_error_for_new_entry(socket, socket.assigns.uploads.avatar.entries)}
  end

  @impl true
  def handle_event("open_remove_avatar_dialog", _params, socket) do
    {:noreply,
     assign(
       socket,
       :remove_avatar_dialog_open,
       !is_nil(socket.assigns.current_user.current_profile_picture_url)
     )}
  end

  @impl true
  def handle_event("cancel_remove_avatar", _params, socket) do
    {:noreply, assign(socket, :remove_avatar_dialog_open, false)}
  end

  @impl true
  def handle_event(
        "remove_avatar",
        _params,
        %{assigns: %{remove_avatar_dialog_open: true}} = socket
      ) do
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
         |> assign(:remove_avatar_dialog_open, false)
         |> assign(:current_user, updated_user)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:remove_avatar_dialog_open, false)
         |> put_flash(:error, "Failed to remove profile picture")}
    end
  end

  def handle_event("remove_avatar", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "save_home_location_time_zone",
        %{"home_location_time_zone" => %{"time_zone" => time_zone}},
        %{assigns: %{pending_home_location: pending, current_user: user}} = socket
      )
      when not is_nil(pending) do
    save_home_location(
      socket,
      user,
      pending.text,
      pending.latitude,
      pending.longitude,
      time_zone
    )
  end

  @impl true
  def handle_info(
        {:location_selected, "profile-location",
         %{display_text: text, latitude: lat, longitude: lng}},
        socket
      ) do
    user = socket.assigns.current_user

    case Huddlz.Accounts.resolve_home_location(user, text, lat, lng,
           load: [:home_location, :home_latitude, :home_longitude, :home_time_zone],
           actor: user
         ) do
      {:ok, updated_user} ->
        {:noreply, home_location_saved(socket, updated_user)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:pending_home_location, %{text: text, latitude: lat, longitude: lng})
         |> assign(:location_error, "Choose a valid time zone for this home location")}
    end
  end

  def handle_info({:location_cleared, "profile-location"}, socket) do
    user = socket.assigns.current_user

    case Huddlz.Accounts.update_home_location(
           user,
           nil,
           nil,
           nil,
           %{home_time_zone: nil},
           load: [:home_location, :home_latitude, :home_longitude, :home_time_zone],
           actor: user
         ) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Home location cleared")
         |> assign(:current_user, updated_user)
         |> assign(:pending_home_location, nil)
         |> assign(:location_error, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to clear location")}
    end
  end

  defp clear_avatar_error_for_new_entry(socket, [_entry | _rest]),
    do: assign(socket, :avatar_error, nil)

  defp clear_avatar_error_for_new_entry(socket, []), do: socket

  defp save_home_location(socket, user, text, latitude, longitude, time_zone) do
    case Huddlz.Accounts.update_home_location(
           user,
           text,
           latitude,
           longitude,
           %{home_time_zone: time_zone},
           load: [:home_location, :home_latitude, :home_longitude, :home_time_zone],
           actor: user
         ) do
      {:ok, updated_user} ->
        {:noreply, home_location_saved(socket, updated_user)}

      {:error, _reason} ->
        {:noreply, assign(socket, :location_error, "Choose a valid time zone")}
    end
  end

  defp home_location_saved(socket, updated_user) do
    socket
    |> put_flash(:info, "Home location updated")
    |> assign(:current_user, updated_user)
    |> assign(:pending_home_location, nil)
    |> assign(:location_error, nil)
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

  defp email_form(user) do
    user
    |> AshPhoenix.Form.for_update(:change_email,
      domain: Huddlz.Accounts,
      forms: [auto?: true],
      actor: user,
      as: "email_change",
      params: %{"email" => ""},
      post_process_errors: &email_change_error/3
    )
    |> to_form()
  end

  defp email_change_error(form, path, error) do
    case AuthFormErrors.post_process(form, path, error) do
      {:email, "has already been taken", _vars} ->
        {:email, "That email is already in use.", []}

      processed_error ->
        processed_error
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
    case Huddlz.Accounts.replace_profile_picture(
           %{
             filename: e.client_name,
             content_type: e.client_type,
             size_bytes: metadata.size_bytes,
             storage_path: metadata.storage_path,
             thumbnail_path: metadata.thumbnail_path,
             user_id: user.id
           },
           actor: user
         ) do
      {:ok, _new_picture} ->
        {:noreply, reload_user_avatar(socket, user, "Profile picture updated successfully")}

      {:error, reason} ->
        cleanup_stored_profile_picture(metadata, reason)

        {:noreply,
         assign(socket, :avatar_error, "Failed to save profile picture. Please try again.")}
    end
  end

  defp handle_upload_result(socket, _user, [{:error, reason}]) do
    {:noreply, assign(socket, :avatar_error, UploadHelpers.format_upload_error(reason))}
  end

  defp handle_upload_result(socket, _user, []) do
    {:noreply, socket}
  end

  defp cleanup_stored_profile_picture(metadata, replacement_error) do
    cleanup_errors =
      [metadata.storage_path, metadata.thumbnail_path]
      |> Enum.map(&ProfilePictures.delete/1)
      |> Enum.reject(&(&1 == :ok))

    if cleanup_errors != [] do
      Logger.error(
        "Failed to clean up profile picture storage after replacement error: " <>
          inspect(%{replacement_error: replacement_error, cleanup_errors: cleanup_errors})
      )
    end
  end

  defp reload_user_avatar(socket, user, flash_message) do
    {:ok, updated_user} = Ash.load(user, [:current_profile_picture_url], actor: user)

    socket
    |> put_flash(:info, flash_message)
    |> assign(:current_user, updated_user)
    |> assign(:avatar_error, nil)
  end
end
