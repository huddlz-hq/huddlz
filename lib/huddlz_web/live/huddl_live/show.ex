defmodule HuddlzWeb.HuddlLive.Show do
  @moduledoc """
  LiveView for displaying a huddl's details, RSVP status, and attendee count.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.MetaHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    case get_huddl(id, group_slug, socket.assigns.current_user) do
      {:ok, huddl} ->
        user = socket.assigns.current_user
        attendance = check_attendance(huddl, user)

        {:noreply,
         socket
         |> assign(:page_title, huddl.title)
         |> assign(:meta, huddl_meta(huddl))
         |> assign(:huddl, huddl)
         |> assign(:attendance, attendance)
         |> assign(:has_rsvped, attendance == :attending)
         |> assign(:waitlist_position, waitlist_position(huddl, user))
         |> assign(:can_edit_huddl, Ash.can?({huddl, :update}, user))
         |> assign(:can_delete_huddl, Ash.can?({huddl, :destroy}, user))}

      {:error, :not_found} ->
        {:noreply,
         handle_error(socket, :not_found,
           resource_name: "Huddl",
           fallback_path: ~p"/groups/#{group_slug}"
         )}

      {:error, :not_authorized} ->
        {:noreply,
         handle_error(socket, :not_authorized,
           resource_name: "huddl",
           action: "access",
           fallback_path: ~p"/discover?#{[scope: "groups"]}"
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="discover"
    >
      <div class={["hero", status_hero_class(@huddl.status)]}>
        <img
          :if={@huddl.display_image_url}
          class="hero-img"
          src={HuddlImages.url(@huddl.display_image_url)}
          alt={@huddl.title}
        />
        <div class="hero-content">
          <span class={["eyebrow", status_eyebrow_class(@huddl.status)]}>
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

          <div :if={@can_edit_huddl || @can_delete_huddl} class="huddl-side-section">
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
                :if={@can_delete_huddl}
                variant={:destructive}
                phx-click="delete_huddl"
                data-confirm="Are you sure you want to delete this huddl?"
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
    </Layouts.app>
    """
  end

  defp render_rsvp_state(%{huddl: %{status: status}} = assigns)
       when status in [:completed, :cancelled] do
    ~H"""
    <div class={["rsvp-banner", status_banner_class(@huddl.status)]}>
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
        <%= if @huddl.status == :cancelled do %>
          <circle cx="12" cy="12" r="9" /><path d="M15 9l-6 6M9 9l6 6" />
        <% else %>
          <path d="M5 13l4 4L19 7" />
        <% end %>
      </svg>
      <span>{status_banner_text(@huddl.status)}</span>
    </div>
    """
  end

  defp render_rsvp_state(%{current_user: nil} = assigns) do
    ~H"""
    <.button variant={:primary} navigate={~p"/sign-in"} class="rsvp-cta">
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
    if event_full?(assigns.huddl) do
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
      <.button variant={:primary} phx-click="join_waitlist" class="rsvp-cta">
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
        {:noreply, put_flash(socket, :error, "Failed to delete huddl.")}
    end
  end

  defp get_huddl(id, group_slug, user) do
    case Communities.get_huddl(id,
           load: [
             :status,
             :rsvp_count,
             :waitlist_count,
             :visible_virtual_link,
             :display_image_url,
             :group,
             creator: [:current_profile_picture_url]
           ],
           actor: user
         ) do
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
    Communities.get_huddl(huddl.id,
      load: [
        :status,
        :rsvp_count,
        :waitlist_count,
        :visible_virtual_link,
        :display_image_url,
        :group,
        creator: [:current_profile_picture_url]
      ],
      actor: user
    )
  end

  defp refresh_attendance(socket, huddl, user) do
    {:ok, reloaded} = reload_huddl(huddl, user)
    attendance = check_attendance(reloaded, user)

    socket
    |> assign(:huddl, reloaded)
    |> assign(:attendance, attendance)
    |> assign(:has_rsvped, attendance == :attending)
    |> assign(:waitlist_position, waitlist_position(reloaded, user))
  end

  defp huddl_meta(huddl) do
    %{
      title: "#{huddl.title} · huddlz",
      description: MetaHelpers.description(huddl, "Find and join this huddl on huddlz."),
      type: "event",
      url: url(~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"),
      image: MetaHelpers.image_url(huddl.display_image_url, HuddlImages)
    }
  end

  defp check_attendance(_huddl, nil), do: :none

  defp check_attendance(huddl, user) do
    case Communities.check_user_rsvp(huddl.id, actor: user) do
      {:ok, []} -> :none
      {:ok, [%{waitlisted_at: nil} | _]} -> :attending
      {:ok, [%{waitlisted_at: _} | _]} -> :waitlisted
      {:error, _} -> :none
    end
  end

  defp waitlist_position(_huddl, nil), do: nil

  defp waitlist_position(huddl, user) do
    require Ash.Query

    case Communities.check_user_rsvp(huddl.id, actor: user) do
      {:ok, [%{waitlisted_at: %DateTime{} = my_at} | _]} ->
        Huddlz.Communities.HuddlAttendee
        |> Ash.Query.filter(
          huddl_id == ^huddl.id and not is_nil(waitlisted_at) and waitlisted_at <= ^my_at
        )
        |> Ash.count!(authorize?: false)

      _ ->
        nil
    end
  end

  defp hero_eyebrow(huddl) do
    "#{event_type_label(huddl.event_type)} · #{status_label(huddl.status)}"
  end

  defp event_type_label(:in_person), do: "In-person huddl"
  defp event_type_label(:virtual), do: "Online huddl"
  defp event_type_label(:hybrid), do: "Hybrid huddl"
  defp event_type_label(_), do: "Huddl"

  defp status_label(:upcoming), do: "Upcoming"
  defp status_label(:in_progress), do: "Happening now"
  defp status_label(:completed), do: "Completed"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(other), do: to_string(other) |> String.capitalize()

  defp status_hero_class(:cancelled), do: "is-cancelled"
  defp status_hero_class(_), do: nil

  defp status_eyebrow_class(:in_progress), do: "eyebrow-warn"
  defp status_eyebrow_class(:completed), do: "eyebrow-muted"
  defp status_eyebrow_class(:cancelled), do: "eyebrow-magenta"
  defp status_eyebrow_class(_), do: nil

  defp status_banner_class(:completed), do: "muted"
  defp status_banner_class(:cancelled), do: "magenta"

  defp status_banner_text(:completed), do: "This huddl has ended"
  defp status_banner_text(:cancelled), do: "This huddl was cancelled"

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
    cond do
      event_full?(huddl) -> "warn"
      capacity_percent(huddl) >= 80 -> "warn"
      true -> nil
    end
  end

  defp event_full?(%{max_attendees: nil}), do: false
  defp event_full?(huddl), do: huddl.rsvp_count >= huddl.max_attendees

  defp capacity_percent(%{max_attendees: nil}), do: 0

  defp capacity_percent(huddl) do
    min(round(huddl.rsvp_count / huddl.max_attendees * 100), 100)
  end

  defp capacity_status(huddl) do
    cond do
      event_full?(huddl) -> "Huddl Full"
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
