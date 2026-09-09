defmodule HuddlzWeb.HuddlLive.Show do
  @moduledoc """
  LiveView for displaying a huddl's details, RSVP status, and attendee count.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Storage.HuddlCoverImages
  alias Huddlz.Storage.HuddlPhotos
  alias HuddlzWeb.Components.Modal
  alias HuddlzWeb.HuddlStatus
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.MetaHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @huddl_loads [
    :status,
    :rsvp_count,
    :waitlist_count,
    :at_capacity,
    :visible_virtual_link,
    :display_image_url,
    group: [:member_count, :current_image_url],
    creator: [:current_profile_picture_url]
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Huddlz.PubSub, "huddl:#{id}")

    {:ok,
     socket
     |> assign(:confirming_delete?, false)
     |> assign(:confirming_cancel?, false)
     |> assign(:confirming_delete_photo_id, nil)
     |> assign(:confirming_delete_photo, nil)
     |> assign(:photo_upload_errors, [])
     |> assign(:selected_photo_url, nil)
     |> assign(:cancel_form, to_form(%{"cancellation_reason" => ""}, as: :cancel))
     |> allow_upload(:huddl_photos,
       accept: HuddlPhotos.allowed_extensions(),
       max_entries: 10,
       max_file_size: HuddlPhotos.max_file_size()
     )}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    case get_huddl(id, group_slug, socket.assigns.current_user) do
      {:ok, huddl} ->
        {:noreply, assign_huddl(socket, huddl)}

      {:error, :not_found} ->
        not_found!()

      {:error, :not_authorized} ->
        not_found!()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="discover"
    >
      <HuddlzWeb.StructuredData.huddl huddl={@huddl} url={@canonical_url} />
      <div class={["huddl-frame", @can_view_photos && "huddl-frame-photos"]}>
        <div class="huddl-main">
          <section
            :if={@huddl.status == :cancelled && is_binary(@huddl.cancellation_reason)}
            id="cancellation-reason"
            class="organizer-update"
            aria-labelledby="organizer-update-title"
          >
            <div class="organizer-update-icon" aria-hidden="true">
              <.icon name="hero-megaphone" class="size-6" />
            </div>
            <div class="organizer-update-copy">
              <h2 id="organizer-update-title">Important update from the organizer</h2>
              <p>{@huddl.cancellation_reason}</p>
            </div>
          </section>

          <section
            :if={@huddl.previous_starts_at && @huddl.status != :cancelled}
            id="schedule-update"
            class="organizer-update"
            aria-labelledby="schedule-update-title"
          >
            <div class="organizer-update-icon" aria-hidden="true">
              <.icon name="hero-calendar-days" class="size-6" />
            </div>
            <div class="organizer-update-copy">
              <h2 id="schedule-update-title">Rescheduled</h2>
              <p>
                Previously scheduled for <time datetime={DateTime.to_iso8601(previous_start(@huddl))}>{Calendar.strftime(previous_start(@huddl), "%a, %b %-d, %Y · %-I:%M %p %Z")}</time>.
              </p>
            </div>
          </section>

          <section
            :if={@huddl.group.archived_at}
            id="huddl-group-archived"
            class="panel"
            role="status"
          >
            <h2>This group is archived</h2>
            <p>This huddl is preserved as read-only history for group members.</p>
          </section>
          <header class={["hero", "huddl-hero", HuddlStatus.hero_class(@huddl.status)]}>
            <div class="hero-media">
              <.cover_image
                :if={@huddl.display_image_url}
                id={"huddl-cover-#{@huddl.id}"}
                class="hero-img"
                image_url={@huddl.display_image_url}
              />
              <div :if={!@huddl.display_image_url} class="hero-fallback" aria-hidden="true">
                <span>{group_initials(@huddl.group.name)}</span>
              </div>
            </div>
            <div class="hero-content">
              <.link
                id="huddl-hero-group"
                navigate={~p"/groups/#{@huddl.group.slug}"}
                class="hero-group"
              >
                <span class="group-mark" aria-hidden="true">
                  {group_initials(@huddl.group.name)}
                </span>
                <span>{@huddl.group.name}</span>
              </.link>
              <span class={["eyebrow", HuddlStatus.eyebrow_class(@huddl.status)]}>
                {hero_eyebrow(@huddl)}
              </span>
              <h1>{@huddl.title}</h1>
              <div class="meta">
                <span :for={{segment, idx} <- Enum.with_index(hero_meta_segments(@huddl))}>
                  <%= if idx > 0 do %>
                    <span class="meta-sep">·</span>
                  <% end %>
                  <span>{segment}</span>
                </span>
              </div>
            </div>
          </header>

          <div class="huddl-intro prose">
            <%= if @huddl.description do %>
              <p :for={paragraph <- description_paragraphs(@huddl.description)}>{paragraph}</p>
            <% else %>
              <p>No description provided.</p>
            <% end %>
          </div>

          <section :if={@can_view_photos} class="huddl-photos">
            <div class="photo-heading">
              <h2>Photos <span class="photo-count">{@photo_count}</span></h2>
              <p>Shared by the people who were here.</p>
            </div>

            <p :if={@photo_count == 0} class="huddl-photos-empty">
              {if @huddl.group.archived_at,
                do: "No photos were shared.",
                else: "No photos yet — be the first to share one!"}
            </p>

            <form
              :if={is_nil(@huddl.group.archived_at)}
              id="huddl-photo-upload-form"
              phx-submit="upload_photos"
              phx-change="validate_photos"
            >
              <label for={@uploads.huddl_photos.ref} class="sr-only">Photos</label>
              <.live_file_input upload={@uploads.huddl_photos} class="hidden" />

              <div class="upload-zone" phx-drop-target={@uploads.huddl_photos.ref}>
                <.icon name="hero-photo" class="size-6 text-[var(--accent)]" />
                <span class="upload-prompt">Drop photos here</span>
                <.button
                  type="button"
                  id="browse-photos"
                  variant={:secondary}
                  phx-click={JS.dispatch("click", to: "##{@uploads.huddl_photos.ref}")}
                >Browse photos</.button>
                <div class="upload-meta muted">JPG, PNG, WebP · 5 MB max · up to 10 photos</div>
              </div>

              <div :for={entry <- @uploads.huddl_photos.entries} class="photo-upload-entry">
                <figure>
                  <.live_img_preview entry={entry} />
                </figure>
                <div class="photo-upload-info">
                  <span class="photo-filename">{entry.client_name}</span>
                  <span class="muted">{if entry.progress == 0,
                    do: "Ready to upload",
                    else: "#{entry.progress}% uploaded"}</span>
                  <progress
                    aria-label={"Upload progress for #{entry.client_name}"}
                    value={entry.progress}
                    max="100"
                  >{entry.progress}%</progress>
                </div>
                <button
                  type="button"
                  class="photo-upload-remove"
                  aria-label={"Remove #{entry.client_name}"}
                  phx-click="cancel_photo_upload"
                  phx-value-ref={entry.ref}
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
                <p :for={err <- upload_errors(@uploads.huddl_photos, entry)} class="upload-error">
                  {photo_upload_error_to_string(err)}
                </p>
              </div>

              <p :for={message <- @photo_upload_errors} class="upload-error" role="alert">
                {message}
              </p>
              <p :for={err <- upload_errors(@uploads.huddl_photos)} class="upload-error">
                {photo_upload_error_to_string(err)}
              </p>

              <.button
                :if={@uploads.huddl_photos.entries != []}
                type="submit"
                variant={:primary}
                phx-disable-with="Uploading…"
              >
                Upload photos
              </.button>
            </form>

            <div id="huddl-photos-grid" phx-update="stream" class="photos-grid">
              <div :for={{dom_id, photo} <- @streams.huddl_photos} id={dom_id} class="photo-tile">
                <button
                  type="button"
                  id={"view-photo-#{photo.id}"}
                  class="photo-open"
                  phx-click={JS.push_focus() |> JS.push("view_photo")}
                  phx-value-url={HuddlPhotos.url(photo.storage_path)}
                  aria-label="View photo"
                >
                  <img src={HuddlPhotos.url(photo.thumbnail_path)} alt="" loading="lazy" />
                </button>
                <span class="photo-credit">{photo.uploader.display_name || "Member"}</span>
                <button
                  :if={
                    is_nil(@huddl.group.archived_at) &&
                      (photo.uploader_id == @current_user.id || @huddl.creator_id == @current_user.id)
                  }
                  type="button"
                  id={"delete-photo-#{photo.id}"}
                  class="photo-delete"
                  phx-click={JS.push_focus() |> JS.push("confirm_delete_photo")}
                  phx-value-id={photo.id}
                  aria-label="Delete photo"
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>
            </div>
          </section>
        </div>

        <aside class="huddl-side">
          <h3>RSVP</h3>

          <ul class="facts">
            <li>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="9" /><path d="M12 6v6l4 2" />
              </svg>
              <div>
                <div class="label">When</div>
                <div id="huddl-schedule-fact" class="value">{format_fact_when(@huddl)}</div>
              </div>
            </li>

            <li :if={@huddl.event_type in [:in_person, :hybrid] && @huddl.physical_location}>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z" />
                <circle cx="12" cy="10" r="3" />
              </svg>
              <div>
                <div class="label">Where</div>
                <div class="value">{@huddl.physical_location}</div>
              </div>
            </li>

            <li :if={@huddl.event_type in [:virtual, :hybrid]}>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <rect x="3" y="6" width="13" height="12" rx="2" /><path d="m16 10 5-3v10l-5-3" />
              </svg>
              <div>
                <div class="label">Virtual access</div>
                <div class="value">
                  <%= cond do %>
                    <% @huddl.status == :completed -> %>
                      <span class="muted">Link expired</span>
                    <% @huddl.visible_virtual_link -> %>
                      <a
                        class="virtual-link-text"
                        href={@huddl.visible_virtual_link}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Join virtually
                      </a>
                    <% @attendance == :waitlisted -> %>
                      <span class="muted">
                        Virtual link available when your RSVP is confirmed
                      </span>
                    <% @current_user -> %>
                      <span class="muted">Virtual link available after RSVP</span>
                    <% true -> %>
                      <span class="muted">Sign in and RSVP to get virtual link</span>
                  <% end %>
                </div>
              </div>
            </li>

            <li>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path d="M17 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
                <circle cx="9.5" cy="7" r="4" />
              </svg>
              <div>
                <div class="label">{capacity_fact_label(@huddl)}</div>
                <div class="value">{format_fact_capacity(@huddl)}</div>
              </div>
            </li>
          </ul>

          <div :if={@huddl.max_attendees} class={["bar", capacity_bar_class(@huddl)]}>
            <span style={"width:#{capacity_percent(@huddl)}%"}></span>
          </div>

          <div class="rsvp-state" data-dock={dock_rsvp?(@huddl)}>
            {render_rsvp_state(assigns)}
            <button
              :if={dock_rsvp?(@huddl)}
              type="button"
              id="huddl-rsvp-share"
              class="rsvp-dock-share"
              aria-label="Share this huddl"
              phx-click={Modal.show_modal("share-huddl-modal")}
            >
              <.icon name="hero-share" class="size-5" />
            </button>
          </div>

          <div class="huddl-side-section">
            <h3>Share</h3>
            <.share_actions id="share-huddl-modal" url={@meta.url} title={@page_title} />
          </div>

          <div
            :if={@can_edit_huddl || @can_publish_huddl || @can_cancel_huddl || @can_delete_huddl}
            class="huddl-side-section"
          >
            <h3>Organize</h3>
            <div class="side-actions">
              <.button
                :if={@can_edit_huddl}
                variant={:secondary}
                navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}/edit"}
              >
                Edit huddl
              </.button>
              <.button
                :if={@can_publish_huddl}
                id="publish-huddl"
                variant={:primary}
                phx-click="publish_huddl"
                phx-disable-with="Publishing…"
              >
                Publish huddl
              </.button>
              <.button
                :if={@can_cancel_huddl}
                variant={:destructive}
                id="open-cancel-huddl-modal"
                phx-click={JS.push_focus() |> JS.push("confirm_cancel_huddl")}
              >
                Cancel huddl
              </.button>
              <.button
                :if={@can_delete_huddl}
                variant={:destructive}
                id="open-delete-huddl-modal"
                phx-click={JS.push_focus() |> JS.push("confirm_delete_huddl")}
              >
                Delete huddl
              </.button>
            </div>
          </div>

          <div id="huddl-group" class="huddl-side-section">
            <h3>Hosted by</h3>
            <.link id="huddl-group-link" navigate={~p"/groups/#{@huddl.group.slug}"} class="group-row">
              <.group_cover group={@huddl.group} id="huddl-group-cover" variant={:thumb} />
              <span class="group-row-copy">
                <span class="group-row-name">{@huddl.group.name}</span>
                <span class="group-row-meta">{group_meta(@huddl.group)}</span>
              </span>
              <.icon name="hero-chevron-right" class="size-4 group-row-chevron" />
            </.link>
            <div class="creator-row">
              <span class="muted">Organized by</span>
              <.avatar user={@huddl.creator} size={:sm} />
              <span>{@huddl.creator.display_name || @huddl.creator.email}</span>
            </div>
          </div>
        </aside>
      </div>

      <.share_modal id="share-huddl-modal" url={@meta.url} label="huddl" />

      <.modal
        :if={@confirming_delete?}
        id="delete-huddl-modal"
        show
        on_cancel={JS.push("cancel_delete_huddl")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-exclamation-triangle" class="h-6 w-6" />
          </div>

          <div class="delete-confirm-copy">
            <span class="eyebrow eyebrow-magenta">Permanent action</span>
            <h2 id="delete-huddl-modal-title">Delete this huddl?</h2>
            <p>
              <strong>{@huddl.title}</strong> will be permanently deleted. All RSVPs will be
              canceled, and everyone who RSVP'd will be notified.
            </p>
            <p :if={@huddl.huddl_template_id} class="delete-confirm-series-note">
              This deletes only the selected occurrence. Other occurrences in the recurring
              series will remain.
            </p>
          </div>
        </div>

        <div class="delete-confirm-actions">
          <.button
            variant={:muted}
            id="cancel-delete-huddl"
            phx-click="cancel_delete_huddl"
          >
            Keep huddl
          </.button>
          <.button
            variant={:destructive}
            class="delete-confirm-submit"
            id="confirm-delete-huddl"
            phx-click="delete_huddl"
            phx-disable-with="Deleting…"
          >
            Delete huddl
          </.button>
        </div>
      </.modal>

      <.modal
        :if={@confirming_cancel?}
        id="cancel-huddl-modal"
        show
        on_cancel={JS.push("cancel_cancel_huddl")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-exclamation-triangle" class="h-6 w-6" />
          </div>

          <div class="delete-confirm-copy">
            <span class="eyebrow eyebrow-magenta">Attendees will be notified</span>
            <h2 id="cancel-huddl-modal-title">Cancel this huddl?</h2>
            <p>
              <strong>{@huddl.title}</strong> will remain in calendars and RSVP history with a
              clear cancelled state.
            </p>
          </div>
        </div>

        <.form for={@cancel_form} id="cancel-huddl-form" phx-submit="cancel_huddl">
          <.input
            field={@cancel_form[:cancellation_reason]}
            type="textarea"
            label="Explanation (optional)"
            placeholder="Share a brief reason with attendees."
          />
          <div class="delete-confirm-actions">
            <.button
              variant={:muted}
              id="keep-published-huddl"
              type="button"
              phx-click="cancel_cancel_huddl"
            >
              Keep huddl
            </.button>
            <.button
              variant={:destructive}
              id="confirm-cancel-huddl"
              type="submit"
              phx-disable-with="Cancelling…"
            >
              Cancel huddl
            </.button>
          </div>
        </.form>
      </.modal>

      <.modal
        :if={@confirming_delete_photo_id}
        id="delete-photo-modal"
        return_focus={"#delete-photo-#{@confirming_delete_photo.id}"}
        show
        on_cancel={JS.push("cancel_delete_photo")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-exclamation-triangle" class="h-6 w-6" />
          </div>

          <div class="delete-confirm-copy">
            <span class="eyebrow eyebrow-magenta">Permanent action</span>
            <h2 id="delete-photo-modal-title">Delete this photo?</h2>
            <p>This photo will be permanently deleted.</p>
          </div>
        </div>

        <figure :if={@confirming_delete_photo} class="photo-delete-preview">
          <img src={@confirming_delete_photo.thumbnail_url} alt={@confirming_delete_photo.filename} />
          <figcaption>Shared by {@confirming_delete_photo.uploader_name}</figcaption>
        </figure>

        <div class="delete-confirm-actions">
          <.button variant={:muted} id="cancel-delete-photo" phx-click="cancel_delete_photo">
            Keep photo
          </.button>
          <.button
            variant={:destructive}
            class="delete-confirm-submit"
            id="confirm-delete-photo"
            phx-click="delete_photo"
            phx-disable-with="Deleting…"
          >
            Delete photo
          </.button>
        </div>
      </.modal>

      <.modal
        :if={@selected_photo_url}
        id="photo-lightbox"
        show
        on_cancel={JS.push("close_photo")}
        class="w-full max-w-4xl"
      >
        <h2 id="photo-lightbox-title" class="sr-only">Photo</h2>
        <div class="photo-lightbox-content" phx-window-keydown="navigate_photo">
          <img
            src={@selected_photo_url}
            alt={@photo_details[@selected_photo_url].filename}
            class="lightbox-image"
          />
          <button
            :if={length(@photo_urls) > 1}
            type="button"
            class="lightbox-nav lightbox-nav-prev"
            phx-click="prev_photo"
            aria-label="Previous photo"
          >
            <.icon name="hero-chevron-left" class="size-5" />
          </button>
          <button
            :if={length(@photo_urls) > 1}
            type="button"
            class="lightbox-nav lightbox-nav-next"
            phx-click="next_photo"
            aria-label="Next photo"
          >
            <.icon name="hero-chevron-right" class="size-5" />
          </button>
        </div>
        <div class="lightbox-actions">
          <div class="lightbox-caption" aria-live="polite" aria-atomic="true">
            <span id="photo-position">{photo_position(@photo_urls, @selected_photo_url)} of {@photo_count}</span>
            <span>Shared by {@photo_details[@selected_photo_url].uploader_name}</span>
          </div>
          <.button variant={:muted} phx-click="close_photo">
            Close
          </.button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp render_rsvp_state(%{huddl: %{status: status}} = assigns)
       when status in [:draft, :completed, :cancelled] do
    ~H"""
    <div class={["rsvp-banner", HuddlStatus.banner_class(@huddl.status)]}>
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <%= if @huddl.status in [:draft, :cancelled] do %>
          <circle cx="12" cy="12" r="9" /><path d="M15 9l-6 6M9 9l6 6" />
        <% else %>
          <path d="M5 13l4 4L19 7" />
        <% end %>
      </svg>
      <span>{HuddlStatus.banner_text(@huddl.status)}</span>
    </div>
    """
  end

  defp render_rsvp_state(%{current_user: nil} = assigns) do
    ~H"""
    <.button
      variant={:primary}
      navigate={rsvp_sign_in_path(@huddl.group.slug, @huddl.id)}
      class="rsvp-cta"
    >
      Sign in to RSVP
    </.button>
    """
  end

  defp render_rsvp_state(%{attendance: :attending} = assigns) do
    ~H"""
    <div class="rsvp-banner cyan">
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d="M5 13l4 4L19 7" />
      </svg>
      <span>You're attending</span>
    </div>
    <a
      :if={@huddl.visible_virtual_link}
      class="btn-secondary virtual-link"
      href={@huddl.visible_virtual_link}
      target="_blank"
      rel="noopener noreferrer"
    >
      <svg
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <rect x="3" y="6" width="13" height="12" rx="2" /><path d="m16 10 5-3v10l-5-3" />
      </svg>
      Join the online room
    </a>
    <.button
      variant={:muted}
      phx-click="cancel_rsvp"
      phx-disable-with="Cancelling..."
      class="rsvp-cta"
    >
      Cancel RSVP
    </.button>
    """
  end

  defp render_rsvp_state(%{attendance: :waitlisted} = assigns) do
    ~H"""
    <div class="rsvp-banner warn">
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" />
      </svg>
      <span>On waitlist · #{@waitlist_position} of {@huddl.waitlist_count}</span>
    </div>
    <.button
      variant={:muted}
      phx-click="leave_waitlist"
      phx-disable-with="Leaving..."
      class="rsvp-cta"
    >
      Leave waitlist
    </.button>
    """
  end

  defp render_rsvp_state(assigns) do
    if assigns.huddl.at_capacity do
      ~H"""
      <div class="rsvp-banner warn">
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" />
        </svg>
        <span>This huddl is full</span>
      </div>
      <.button
        variant={:primary}
        phx-click="join_waitlist"
        phx-disable-with="Joining waitlist..."
        class="rsvp-cta"
      >
        Join waitlist
      </.button>
      """
    else
      ~H"""
      <.button
        variant={:primary}
        phx-click="rsvp"
        phx-disable-with="RSVPing..."
        class="rsvp-cta"
      >
        RSVP to this huddl
      </.button>
      <div :if={@huddl.event_type in [:virtual, :hybrid]} class="virtual-hint">
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.8"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <rect x="3" y="6" width="13" height="12" rx="2" /><path d="m16 10 5-3v10l-5-3" />
        </svg>
        <span>Online link visible after you RSVP.</span>
      </div>
      """
    end
  end

  # On phones the RSVP block is pinned to the bottom edge, but only while
  # there is something to do: a finished, cancelled or draft huddl shows a
  # status banner that can stay in the aside.
  defp dock_rsvp?(%{status: status}) when status in [:draft, :completed, :cancelled], do: nil
  defp dock_rsvp?(_huddl), do: true

  defp rsvp_sign_in_path(group_slug, huddl_id) do
    return_to = "/groups/#{group_slug}/huddlz/#{huddl_id}"
    "/sign-in?" <> URI.encode_query(return_to: return_to)
  end

  defp upload_one_photo(path, entry, huddl_id, user) do
    case HuddlPhotos.store(path, entry.client_name, entry.client_type, huddl_id) do
      {:ok, metadata} -> create_huddl_photo_record(metadata, entry, huddl_id, user)
      {:error, reason} -> {:ok, {:error, {entry.client_name, reason}}}
    end
  end

  defp create_huddl_photo_record(metadata, entry, huddl_id, user) do
    attrs = %{
      filename: entry.client_name,
      content_type: entry.client_type,
      size_bytes: metadata.size_bytes,
      storage_path: metadata.storage_path,
      thumbnail_path: metadata.thumbnail_path,
      huddl_id: huddl_id
    }

    case Communities.create_huddl_photo(attrs, actor: user) do
      {:ok, photo} ->
        {:ok, {:ok, photo}}

      {:error, reason} ->
        # store/4 already wrote the original + thumbnail to storage; since the
        # database record was never created, clean those orphaned files up.
        # Best-effort: if delete itself fails, we still report the original
        # create error to the user rather than masking it.
        HuddlPhotos.delete(metadata.storage_path)
        HuddlPhotos.delete(metadata.thumbnail_path)
        {:ok, {:error, {entry.client_name, reason}}}
    end
  end

  defp maybe_put_upload_result_flash(socket, _successes, 0), do: socket

  defp maybe_put_upload_result_flash(socket, successes, total),
    do: put_upload_result_flash(socket, successes, total)

  defp put_upload_result_flash(socket, total, total),
    do: put_flash(socket, :info, "Photos uploaded.")

  defp put_upload_result_flash(socket, 0, _total),
    do: put_flash(socket, :error, "No photos uploaded. Check the details below.")

  defp put_upload_result_flash(socket, successes, total) do
    put_flash(
      socket,
      :error,
      "#{successes} of #{total} photos uploaded. Check the details below."
    )
  end

  defp photo_upload_error_to_string(:too_large), do: "Each photo must be 5 MB or smaller."

  defp photo_upload_error_to_string(reason)
       when reason in [
              :not_accepted,
              :invalid_extension,
              :invalid_image,
              "Invalid file type. Allowed: JPG, PNG, WebP"
            ],
       do: "Choose a JPG, PNG, or WebP image."

  defp photo_upload_error_to_string(:too_many_files), do: "Choose up to 10 photos at a time."
  defp photo_upload_error_to_string(_), do: "Could not save this photo. Please try again."

  @impl true
  def handle_event("rsvp", _, socket) do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user

    case Communities.rsvp_huddl(huddl, %{}, actor: user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully RSVPed to this huddl!")
         |> refresh_attendance(huddl, user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to RSVP. Please try again.")}
    end
  end

  @impl true
  def handle_event("join_waitlist", _, socket) do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user

    case Communities.join_waitlist_huddl(huddl, %{}, actor: user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added to the waitlist. We'll email you if a spot opens up.")
         |> refresh_attendance(huddl, user)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Couldn't join the waitlist. Please try again.")}
    end
  end

  @impl true
  def handle_event("validate_photos", _params, socket) do
    upload = socket.assigns.uploads.huddl_photos

    {socket, errors, _accepted} =
      Enum.reduce(upload.entries, {socket, [], 0}, fn entry, {socket, errors, accepted} ->
        reasons = upload_errors(upload, entry)

        reasons =
          if accepted >= upload.max_entries, do: [:too_many_files | reasons], else: reasons

        if reasons == [] do
          {socket, errors, accepted + 1}
        else
          messages =
            Enum.map(reasons, &(entry.client_name <> ": " <> photo_upload_error_to_string(&1)))

          {cancel_upload(socket, :huddl_photos, entry.ref), errors ++ messages, accepted}
        end
      end)

    {:noreply, assign(socket, :photo_upload_errors, errors)}
  end

  @impl true
  def handle_event("cancel_photo_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :huddl_photos, ref)}
  end

  @impl true
  def handle_event("upload_photos", _params, %{assigns: %{can_view_photos: false}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_photos", _params, socket) do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user

    results =
      consume_uploaded_entries(socket, :huddl_photos, fn %{path: path}, entry ->
        upload_one_photo(path, entry, huddl.id, user)
      end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _photo}, &1))

    socket = load_photos(socket, huddl, user, socket.assigns.can_view_photos)

    errors =
      Enum.map(failures, fn {:error, {name, reason}} ->
        name <> ": " <> photo_upload_error_to_string(reason)
      end)

    socket = update(socket, :photo_upload_errors, &(&1 ++ errors))
    {:noreply, maybe_put_upload_result_flash(socket, length(successes), length(results))}
  end

  @impl true
  def handle_event("confirm_delete_photo", %{"id" => id}, socket) do
    photo = socket.assigns.photo_details |> Map.values() |> Enum.find(&(&1.id == id))

    {:noreply,
     socket
     |> assign(:confirming_delete_photo, photo)
     |> assign(:confirming_delete_photo_id, if(photo, do: id))}
  end

  @impl true
  def handle_event("cancel_delete_photo", _params, socket) do
    {:noreply, assign(socket, :confirming_delete_photo_id, nil)}
  end

  @impl true
  def handle_event("delete_photo", _params, socket) do
    user = socket.assigns.current_user
    photo_id = socket.assigns.confirming_delete_photo_id

    with {:ok, photo} <- Communities.get_huddl_photo_by_id(photo_id, actor: user),
         :ok <- Communities.destroy_huddl_photo(photo, actor: user) do
      {:noreply,
       socket
       |> assign(:confirming_delete_photo_id, nil)
       |> assign(:confirming_delete_photo, nil)
       |> load_photos(socket.assigns.huddl, user, socket.assigns.can_view_photos)}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:confirming_delete_photo_id, nil)
         |> put_flash(:error, "Failed to delete photo.")}
    end
  end

  @impl true
  def handle_event("view_photo", %{"url" => url}, socket) do
    if url in socket.assigns.photo_urls do
      {:noreply, assign(socket, :selected_photo_url, url)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_photo", _params, socket) do
    {:noreply, assign(socket, :selected_photo_url, nil)}
  end

  @impl true
  def handle_event("navigate_photo", %{"key" => "ArrowRight"}, socket),
    do: {:noreply, shift_selected_photo(socket, 1)}

  def handle_event("navigate_photo", %{"key" => "ArrowLeft"}, socket),
    do: {:noreply, shift_selected_photo(socket, -1)}

  def handle_event("navigate_photo", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("next_photo", _params, socket) do
    {:noreply, shift_selected_photo(socket, 1)}
  end

  @impl true
  def handle_event("prev_photo", _params, socket) do
    {:noreply, shift_selected_photo(socket, -1)}
  end

  @impl true
  def handle_event(action, _, socket) when action in ["cancel_rsvp", "leave_waitlist"] do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user
    waitlist? = socket.assigns.attendance == :waitlisted

    case Communities.cancel_rsvp_huddl(huddl, %{}, actor: user) do
      {:ok, _} ->
        flash_msg =
          if waitlist?, do: "Removed from the waitlist.", else: "RSVP cancelled successfully"

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> refresh_attendance(huddl, user)}

      {:error, %Ash.Error.Forbidden{}} ->
        {:noreply, put_flash(socket, :error, "You can only cancel your own RSVP.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel RSVP. Please try again.")}
    end
  end

  def handle_event("confirm_delete_huddl", _, socket) do
    {:noreply, assign(socket, :confirming_delete?, true)}
  end

  def handle_event("confirm_cancel_huddl", _, socket) do
    {:noreply, assign(socket, :confirming_cancel?, true)}
  end

  def handle_event("cancel_cancel_huddl", _, socket) do
    {:noreply, assign(socket, :confirming_cancel?, false)}
  end

  def handle_event("publish_huddl", _, socket) do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user

    case Communities.publish_huddl(huddl, actor: user) do
      {:ok, _published} ->
        {:noreply,
         socket
         |> put_flash(:info, "Huddl published. Members can now discover and RSVP to it.")
         |> push_navigate(to: ~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "This huddl could not be published.")}
    end
  end

  def handle_event("cancel_huddl", %{"cancel" => params}, socket) do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user

    case Communities.cancel_huddl(huddl, params["cancellation_reason"], actor: user) do
      {:ok, _cancelled} ->
        {:noreply,
         socket
         |> put_flash(:info, "Huddl cancelled. Attendees have been notified.")
         |> push_navigate(to: ~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}")}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:confirming_cancel?, false)
         |> put_flash(:error, "This huddl could not be cancelled.")}
    end
  end

  def handle_event("cancel_delete_huddl", _, socket) do
    {:noreply, assign(socket, :confirming_delete?, false)}
  end

  def handle_event("delete_huddl", _, socket) do
    huddl = socket.assigns.huddl
    user = socket.assigns.current_user

    case Communities.destroy_huddl(huddl, actor: user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Huddl deleted successfully!")
         |> redirect(to: ~p"/groups/#{huddl.group.slug}")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:confirming_delete?, false)
         |> put_flash(:error, "Failed to delete huddl.")}
    end
  end

  @impl true
  def handle_info({:huddl_changed, id}, %{assigns: %{huddl: %{id: id} = huddl}} = socket) do
    {:noreply, refresh_attendance(socket, huddl, socket.assigns.current_user)}
  end

  defp get_huddl(id, group_slug, user) do
    case Communities.get_huddl(id, load: @huddl_loads, actor: user) do
      {:ok, huddl} ->
        if huddl.group.slug == group_slug do
          {:ok, huddl}
        else
          {:error, :not_found}
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :not_found}

      {:error, _} ->
        {:error, :not_authorized}
    end
  end

  defp reload_huddl(huddl, user) do
    Communities.get_huddl(huddl.id, load: @huddl_loads, actor: user)
  end

  defp refresh_attendance(socket, huddl, user) do
    case reload_huddl(huddl, user) do
      {:ok, reloaded} ->
        assign_huddl(socket, reloaded)

      {:error, _} ->
        socket
        |> put_flash(:error, "This huddl is no longer available.")
        |> push_navigate(to: ~p"/groups/#{huddl.group.slug}")
    end
  end

  defp assign_huddl(socket, huddl) do
    user = socket.assigns.current_user
    {attendance, waitlist_position} = attendance_info(huddl, user)

    can_view_photos = can_view_photos?(huddl, user, attendance)

    socket
    |> assign(:page_title, huddl.title)
    |> assign(:meta, huddl_meta(huddl))
    |> assign(:canonical_url, public_url(huddl))
    |> assign(:huddl, huddl)
    |> assign(:can_view_photos, can_view_photos)
    |> assign(:attendance, attendance)
    |> assign(:waitlist_position, waitlist_position)
    |> assign(
      :can_edit_huddl,
      is_nil(huddl.group.archived_at) && editable_lifecycle?(huddl) &&
        Communities.can_update_huddl?(user, huddl)
    )
    |> assign(
      :can_publish_huddl,
      is_nil(huddl.group.archived_at) && huddl.lifecycle_state == :draft &&
        Communities.can_publish_huddl?(user, huddl)
    )
    |> assign(
      :can_cancel_huddl,
      is_nil(huddl.group.archived_at) && cancellable_lifecycle?(huddl) &&
        Communities.can_cancel_huddl?(user, huddl)
    )
    |> assign(
      :can_delete_huddl,
      is_nil(huddl.group.archived_at) && Communities.can_destroy_huddl?(user, huddl)
    )
    |> load_photos(huddl, user, can_view_photos)
  end

  defp huddl_meta(huddl) do
    %{
      title: "#{huddl.title} · huddlz",
      description: MetaHelpers.description(huddl, "Find and join this huddl on huddlz."),
      type: "event",
      url: url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"),
      image:
        MetaHelpers.image_url(huddl.display_image_url, HuddlCoverImages) ||
          url(~p"/og/huddlz/#{huddl.id}/card.png")
    }
  end

  defp previous_start(huddl),
    do: DateTime.shift_zone!(huddl.previous_starts_at, huddl.previous_time_zone)

  defp public_url(
         %{is_private: false, group: %{is_public: true, archived_at: nil}, lifecycle_state: state} =
           huddl
       )
       when state in [:published, :completed, :cancelled],
       do: huddl_meta(huddl).url

  defp public_url(_huddl), do: nil

  defp attendance_info(_huddl, nil), do: {:none, nil}

  defp attendance_info(huddl, user) do
    case Communities.check_user_rsvp(huddl.id, actor: user) do
      {:ok, [%{waitlisted_at: nil} | _]} ->
        {:attending, nil}

      {:ok, [%{waitlisted_at: %DateTime{} = waitlisted_at} | _]} ->
        {:waitlisted, waitlist_position(huddl, waitlisted_at)}

      _ ->
        {:none, nil}
    end
  end

  defp waitlist_position(huddl, %DateTime{} = waitlisted_at) do
    require Ash.Query

    Huddlz.Communities.HuddlAttendee
    |> Ash.Query.filter(
      huddl_id == ^huddl.id and not is_nil(waitlisted_at) and waitlisted_at <= ^waitlisted_at
    )
    |> Ash.count!(authorize?: false)
  end

  defp group_meta(group) do
    members =
      case group.member_count do
        1 -> "1 member"
        count -> "#{count} members"
      end

    [members, group.location, if(group.is_public, do: nil, else: "Private group")]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp hero_eyebrow(huddl) do
    "#{event_type_label(huddl.event_type)} · #{HuddlStatus.label(huddl.status)}"
  end

  defp editable_lifecycle?(%{lifecycle_state: :draft}), do: true

  defp editable_lifecycle?(%{lifecycle_state: :published, ends_at: ends_at}),
    do: DateTime.after?(ends_at, DateTime.utc_now())

  defp editable_lifecycle?(_huddl), do: false

  defp can_view_photos?(%{status: :completed} = huddl, %{id: user_id}, attendance) do
    attendance == :attending || huddl.creator_id == user_id
  end

  defp can_view_photos?(_huddl, _user, _attendance), do: false

  defp load_photos(socket, huddl, user, true) do
    {:ok, photos} = Communities.list_huddl_photos(huddl.id, actor: user)

    urls = Enum.map(photos, &HuddlPhotos.url(&1.storage_path))

    socket
    |> assign(
      :selected_photo_url,
      if(socket.assigns.selected_photo_url in urls, do: socket.assigns.selected_photo_url)
    )
    |> assign(
      :photo_details,
      Map.new(photos, fn photo ->
        {HuddlPhotos.url(photo.storage_path),
         %{
           id: photo.id,
           filename: photo.filename,
           thumbnail_url: HuddlPhotos.url(photo.thumbnail_path),
           uploader_name: photo.uploader.display_name || "Member"
         }}
      end)
    )
    |> assign(:photo_count, length(photos))
    |> restream_photos(photos, urls)
  end

  defp load_photos(socket, _huddl, _user, false) do
    socket
    |> assign(:photo_details, %{})
    |> assign(:selected_photo_url, nil)
    |> assign(:confirming_delete_photo_id, nil)
    |> assign(:confirming_delete_photo, nil)
    |> assign(:photo_count, 0)
    |> restream_photos([], [])
  end

  # Every photo upload broadcasts `huddl_changed`, which lands here as a full
  # refresh. Resetting the stream on each one tears the tiles down and rebuilds
  # them, which drops keyboard focus mid-interaction, so only reset when the set
  # of photos actually changed. The first load always streams: `photo_urls` is
  # unset until then.
  defp restream_photos(socket, photos, urls) do
    changed? = Map.get(socket.assigns, :photo_urls) != urls

    socket = assign(socket, :photo_urls, urls)

    if changed?, do: stream(socket, :huddl_photos, photos, reset: true), else: socket
  end

  defp photo_position(urls, url), do: (Enum.find_index(urls, &(&1 == url)) || 0) + 1

  defp shift_selected_photo(socket, offset) do
    urls = socket.assigns.photo_urls
    count = length(urls)

    case Enum.find_index(urls, &(&1 == socket.assigns.selected_photo_url)) do
      nil ->
        socket

      index ->
        next_url = Enum.at(urls, rem(index + offset + count, count))
        assign(socket, :selected_photo_url, next_url)
    end
  end

  defp cancellable_lifecycle?(%{lifecycle_state: :published, ends_at: ends_at}),
    do: DateTime.after?(ends_at, DateTime.utc_now())

  defp cancellable_lifecycle?(_huddl), do: false

  defp event_type_label(:in_person), do: "In-person huddl"
  defp event_type_label(:virtual), do: "Online huddl"
  defp event_type_label(:hybrid), do: "Hybrid huddl"
  defp event_type_label(_), do: "Huddl"

  # The group is named by the linked mark above the title, so the meta row
  # only carries the schedule and place.
  defp hero_meta_segments(huddl) do
    [
      hero_when_segment(huddl),
      hero_location_segment(huddl)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp hero_when_segment(%{status: :in_progress} = huddl) do
    if huddl.ends_at do
      "Started #{format_time_only(huddl.starts_at, huddl.time_zone)} · ends #{format_time_only(huddl.ends_at, huddl.time_zone)}"
    else
      "Started #{format_time_only(huddl.starts_at, huddl.time_zone)}"
    end
  end

  defp hero_when_segment(%{status: :cancelled} = huddl) do
    "Was scheduled for #{format_short_date(huddl.starts_at, huddl.time_zone)}"
  end

  defp hero_when_segment(%{status: :completed} = huddl) do
    "#{format_short_date(huddl.starts_at, huddl.time_zone)} · #{huddl.rsvp_count} attended"
  end

  defp hero_when_segment(huddl) do
    "#{format_short_date(huddl.starts_at, huddl.time_zone)} · #{format_time_only(huddl.starts_at, huddl.time_zone)}"
  end

  defp hero_location_segment(%{event_type: :hybrid, physical_location: loc}) when is_binary(loc),
    do: "#{loc} · & online"

  defp hero_location_segment(%{event_type: :in_person, physical_location: loc})
       when is_binary(loc),
       do: loc

  defp hero_location_segment(%{event_type: :virtual}), do: "Online"
  defp hero_location_segment(_), do: nil

  defp format_fact_when(huddl) do
    starts_at = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)
    ends_at = huddl.ends_at && DateTime.shift_zone!(huddl.ends_at, huddl.time_zone)

    cond do
      ends_at && same_day?(starts_at, ends_at) ->
        "#{format_short_date(starts_at)} · #{format_time_only(starts_at)} – #{format_time_only(ends_at)} #{starts_at.zone_abbr}"

      ends_at ->
        "#{format_short_date(starts_at)} #{format_time_only(starts_at)} → #{format_short_date(ends_at)} #{format_time_only(ends_at)} #{starts_at.zone_abbr}"

      true ->
        "#{format_short_date(starts_at)} · #{format_time_only(starts_at)} #{starts_at.zone_abbr}"
    end
  end

  defp same_day?(%DateTime{} = a, %DateTime{} = b),
    do: DateTime.to_date(a) == DateTime.to_date(b)

  defp capacity_fact_label(%{status: :completed}), do: "Attended"
  defp capacity_fact_label(_), do: "Capacity"

  defp format_fact_capacity(%{status: :completed} = huddl) do
    case huddl.rsvp_count do
      0 -> "No one attended"
      1 -> "1 person attended"
      n -> "#{n} people attended"
    end
  end

  defp format_fact_capacity(%{rsvp_count: 0, max_attendees: nil}), do: "Be the first to RSVP!"

  defp format_fact_capacity(%{rsvp_count: count, max_attendees: nil}),
    do: "#{count} #{person_label(count)} attending"

  defp format_fact_capacity(%{max_attendees: max} = huddl) when is_integer(max) and max > 0 do
    base = "#{huddl.rsvp_count}/#{max} spots filled · #{capacity_status(huddl)}"

    case huddl.waitlist_count do
      n when is_integer(n) and n > 0 -> "#{base} · #{n} waitlisted"
      _ -> base
    end
  end

  defp person_label(1), do: "person"
  defp person_label(_), do: "people"

  defp capacity_bar_class(huddl) do
    if capacity_percent(huddl) >= 80, do: "warn"
  end

  defp capacity_percent(%{max_attendees: nil}), do: 0

  defp capacity_percent(huddl) do
    min(round(huddl.rsvp_count / huddl.max_attendees * 100), 100)
  end

  defp capacity_status(huddl) do
    cond do
      huddl.at_capacity -> "Huddl Full"
      capacity_percent(huddl) >= 80 -> "Almost full"
      capacity_percent(huddl) >= 50 -> "Filling up"
      true -> "Plenty of space"
    end
  end

  defp description_paragraphs(text) do
    text
    |> String.split(~r/\r?\n\r?\n/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp format_short_date(datetime, time_zone) do
    datetime
    |> DateTime.shift_zone!(time_zone)
    |> format_short_date()
  end

  defp format_short_date(datetime) do
    Calendar.strftime(datetime, "%a, %b %-d")
  end

  defp format_time_only(datetime, time_zone) do
    datetime
    |> DateTime.shift_zone!(time_zone)
    |> format_time_only()
  end

  defp format_time_only(datetime) do
    Calendar.strftime(datetime, "%-I:%M %p")
  end
end
