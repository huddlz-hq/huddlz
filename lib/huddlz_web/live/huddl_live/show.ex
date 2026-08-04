defmodule HuddlzWeb.HuddlLive.Show do
  @moduledoc """
  LiveView for displaying a huddl's details, RSVP status, and attendee count.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Storage.HuddlCoverImages
  alias Huddlz.Storage.HuddlPhotos
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
    :group,
    creator: [:current_profile_picture_url]
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:confirming_delete?, false)
     |> assign(:confirming_cancel?, false)
     |> assign(:cancel_form, to_form(%{"cancellation_reason" => ""}, as: :cancel))}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    case get_huddl(id, group_slug, socket.assigns.current_user) do
      {:ok, huddl} ->
        user = socket.assigns.current_user
        {attendance, waitlist_position} = attendance_info(huddl, user)
        can_view_photos = can_view_photos?(huddl, user, attendance)

        {:noreply,
         socket
         |> assign(:page_title, huddl.title)
         |> assign(:meta, huddl_meta(huddl))
         |> assign(:huddl, huddl)
         |> assign(:attendance, attendance)
         |> assign(:waitlist_position, waitlist_position)
         |> assign(:can_view_photos, can_view_photos)
         |> assign(
           :can_edit_huddl,
           editable_lifecycle?(huddl) && Communities.can_update_huddl?(user, huddl)
         )
         |> assign(
           :can_publish_huddl,
           huddl.lifecycle_state == :draft && Communities.can_publish_huddl?(user, huddl)
         )
         |> assign(
           :can_cancel_huddl,
           cancellable_lifecycle?(huddl) && Communities.can_cancel_huddl?(user, huddl)
         )
         |> assign(
           :can_delete_huddl,
           Communities.can_destroy_huddl?(user, huddl)
         )
         |> load_photos(huddl, user, can_view_photos)}

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
      <section
        :if={@huddl.status == :cancelled && @huddl.cancellation_reason}
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

      <div class={["hero", "huddl-hero", HuddlStatus.hero_class(@huddl.status)]}>
        <div class="hero-media">
          <.huddl_cover_image
            :if={@huddl.display_image_url}
            id={"huddl-cover-#{@huddl.id}"}
            class="hero-img"
            image_url={@huddl.display_image_url}
          />
        </div>
        <div class="hero-content">
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
      </div>

      <div class="huddl-frame">
        <div class="huddl-intro prose">
          <%= if @huddl.description do %>
            <p :for={paragraph <- description_paragraphs(@huddl.description)}>{paragraph}</p>
          <% else %>
            <p>No description provided.</p>
          <% end %>
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
                <div class="value">{format_fact_when(@huddl)}</div>
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

          <div class="rsvp-state">
            {render_rsvp_state(assigns)}
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

          <div class="huddl-side-section">
            <h3>Organized by</h3>
            <div class="creator-row">
              <.avatar user={@huddl.creator} size={:sm} />
              <span>{@huddl.creator.display_name || @huddl.creator.email}</span>
            </div>
          </div>
        </aside>
      </div>

      <section :if={@can_view_photos} class="huddl-photos">
        <h2>Photos</h2>

        <p :if={@photo_count == 0} class="huddl-photos-empty">
          No photos yet — be the first to share one!
        </p>

        <div id="huddl-photos-grid" phx-update="stream" class="photos-grid">
          <div :for={{dom_id, photo} <- @streams.huddl_photos} id={dom_id} class="photo-tile">
            <img src={HuddlPhotos.url(photo.thumbnail_path)} alt="" loading="lazy" />
          </div>
        </div>
      </section>

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

  defp rsvp_sign_in_path(group_slug, huddl_id) do
    return_to = "/groups/#{group_slug}/huddlz/#{huddl_id}"
    "/sign-in?" <> URI.encode_query(return_to: return_to)
  end

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
        {attendance, waitlist_position} = attendance_info(reloaded, user)

        socket
        |> assign(:huddl, reloaded)
        |> assign(:attendance, attendance)
        |> assign(:waitlist_position, waitlist_position)

      {:error, _} ->
        socket
        |> put_flash(:error, "This huddl is no longer available.")
        |> push_navigate(to: ~p"/groups/#{huddl.group.slug}")
    end
  end

  defp huddl_meta(huddl) do
    %{
      title: "#{huddl.title} · huddlz",
      description: MetaHelpers.description(huddl, "Find and join this huddl on huddlz."),
      type: "event",
      url: url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"),
      image: MetaHelpers.image_url(huddl.display_image_url, HuddlCoverImages)
    }
  end

  defp attendance_info(_huddl, nil), do: {:none, nil}

  defp attendance_info(huddl, user) do
    case Communities.check_user_rsvp(huddl.id, actor: user) do
      {:ok, [%{waitlisted_at: nil} | _]} ->
        {:attending, nil}

      {:ok, [%{waitlisted_at: %DateTime{} = my_at} | _]} ->
        {:waitlisted, waitlist_position(huddl, my_at)}

      _ ->
        {:none, nil}
    end
  end

  defp waitlist_position(huddl, %DateTime{} = my_at) do
    require Ash.Query

    Huddlz.Communities.HuddlAttendee
    |> Ash.Query.filter(
      huddl_id == ^huddl.id and not is_nil(waitlisted_at) and waitlisted_at <= ^my_at
    )
    |> Ash.count!(authorize?: false)
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

    socket
    |> assign(:photo_count, length(photos))
    |> stream(:huddl_photos, photos, reset: true)
  end

  defp load_photos(socket, _huddl, _user, false) do
    socket
    |> assign(:photo_count, 0)
    |> stream(:huddl_photos, [], reset: true)
  end

  defp cancellable_lifecycle?(%{lifecycle_state: :published, ends_at: ends_at}),
    do: DateTime.after?(ends_at, DateTime.utc_now())

  defp cancellable_lifecycle?(_huddl), do: false

  defp event_type_label(:in_person), do: "In-person huddl"
  defp event_type_label(:virtual), do: "Online huddl"
  defp event_type_label(:hybrid), do: "Hybrid huddl"
  defp event_type_label(_), do: "Huddl"

  defp hero_meta_segments(huddl) do
    [
      huddl.group.name,
      hero_when_segment(huddl),
      hero_location_segment(huddl)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp hero_when_segment(%{status: :in_progress} = huddl) do
    if huddl.ends_at do
      "Started #{format_time_only(huddl.starts_at)} · ends #{format_time_only(huddl.ends_at)}"
    else
      "Started #{format_time_only(huddl.starts_at)}"
    end
  end

  defp hero_when_segment(%{status: :cancelled} = huddl) do
    "Was scheduled for #{format_short_date(huddl.starts_at)}"
  end

  defp hero_when_segment(%{status: :completed} = huddl) do
    "#{format_short_date(huddl.starts_at)} · #{huddl.rsvp_count} attended"
  end

  defp hero_when_segment(huddl) do
    "#{format_short_date(huddl.starts_at)} · #{format_time_only(huddl.starts_at)}"
  end

  defp hero_location_segment(%{event_type: :hybrid, physical_location: loc}) when is_binary(loc),
    do: "#{loc} · & online"

  defp hero_location_segment(%{event_type: :in_person, physical_location: loc})
       when is_binary(loc),
       do: loc

  defp hero_location_segment(%{event_type: :virtual}), do: "Online"
  defp hero_location_segment(_), do: nil

  defp format_fact_when(huddl) do
    cond do
      huddl.ends_at && same_day?(huddl.starts_at, huddl.ends_at) ->
        "#{format_short_date(huddl.starts_at)} · #{format_time_only(huddl.starts_at)} – #{format_time_only(huddl.ends_at)} UTC"

      huddl.ends_at ->
        "#{format_short_date(huddl.starts_at)} #{format_time_only(huddl.starts_at)} → #{format_short_date(huddl.ends_at)} #{format_time_only(huddl.ends_at)} UTC"

      true ->
        "#{format_short_date(huddl.starts_at)} · #{format_time_only(huddl.starts_at)} UTC"
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

  defp format_short_date(datetime) do
    Calendar.strftime(datetime, "%a, %b %-d")
  end

  defp format_time_only(datetime) do
    Calendar.strftime(datetime, "%-I:%M %p")
  end
end
