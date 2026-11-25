defmodule HuddlzWeb.Components.HuddlForm do
  @moduledoc """
  Presentation primitives shared by the huddl create and edit forms:
  the huddl-format radio cards, the duration select options, and the
  basics/format/when/where/capacity panels and location modal.

  ```
  <.basics_panel form={@form} />
  <.format_panel form={@form} />
  <.when_panel form={@form} selected_location={@selected_location}>
    <:recurring_controls>...</:recurring_controls>
  </.when_panel>
  <.where_panel form={@form} show_physical_location={@show_physical_location}
    show_virtual_link={@show_virtual_link} group_locations={@group_locations}
    selected_location={@selected_location} new_location_path={~p"..."} />
  <.capacity_panel form={@form} is_public={@group.is_public} />

  <.location_modal live_action={@live_action} cancel_path={~p"..."}
    group={@group} actor={@current_user} />
  ```
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Icon, only: [icon: 1]

  import HuddlzWeb.Components.Input,
    only: [input: 1, select: 1, textarea: 1, field_errors: 1, toggle: 1]

  import HuddlzWeb.Components.Modal, only: [modal: 1]

  alias Phoenix.LiveView.JS

  @duration_options [
    {"30 minutes", "30"},
    {"1 hour", "60"},
    {"1.5 hours", "90"},
    {"2 hours", "120"},
    {"2.5 hours", "150"},
    {"3 hours", "180"},
    {"4 hours", "240"},
    {"6 hours", "360"}
  ]

  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :title, :string, required: true
  attr :desc, :string, required: true
  slot :icon, required: true

  defp event_type_option(assigns) do
    radio_id = "event-type-#{assigns.value}"
    assigns = assign(assigns, :radio_id, radio_id)

    ~H"""
    <div class={["event-type-option", to_string(@field.value) == @value && "is-active"]}>
      <input
        id={@radio_id}
        type="radio"
        name={@field.name}
        value={@value}
        checked={to_string(@field.value) == @value}
        class="choice-control-input"
      />
      <label for={@radio_id} class="huddl-format-hitbox">
        <span class="sr-only">{@title}</span>
      </label>
      <div class="event-type-icon" aria-hidden="true">{render_slot(@icon)}</div>
      <div>
        <div class="event-type-title">{@title}</div>
        <div class="event-type-desc">{@desc}</div>
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  def event_type_grid(assigns) do
    ~H"""
    <fieldset class="huddl-format-fieldset">
      <legend class="sr-only">Huddl format</legend>
      <div class="event-type-grid">
        <.event_type_option
          field={@field}
          value="in_person"
          title="In person"
          desc="Single physical location."
        >
          <:icon>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z" /><circle
                cx="12"
                cy="10"
                r="3"
              />
            </svg>
          </:icon>
        </.event_type_option>
        <.event_type_option
          field={@field}
          value="virtual"
          title="Virtual"
          desc="Online only — no physical address."
        >
          <:icon>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <rect x="3" y="6" width="13" height="12" rx="2" /><path d="m16 10 5-3v10l-5-3" />
            </svg>
          </:icon>
        </.event_type_option>
        <.event_type_option
          field={@field}
          value="hybrid"
          title="Hybrid"
          desc="In-person plus an online stream."
        >
          <:icon>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z" /><circle
                cx="12"
                cy="10"
                r="3"
              /><path d="m22 22-2-2" />
            </svg>
          </:icon>
        </.event_type_option>
      </div>
    </fieldset>
    """
  end

  def duration_options, do: @duration_options

  defp duration_options(value) when value in [nil, ""], do: @duration_options

  defp duration_options(value) do
    value = to_string(value)

    if Enum.any?(@duration_options, fn {_label, minutes} -> minutes == value end) do
      @duration_options
    else
      [{"#{value} minutes", value} | @duration_options]
    end
  end

  # ---------------------------------------------------------------------------
  # Shared panels
  # ---------------------------------------------------------------------------

  attr :form, :map, required: true

  def basics_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>The basics</h2>
      </div>
      <div class="form-grid">
        <.input
          field={@form[:title]}
          label="Title"
          placeholder="e.g. Ash Framework workshop"
          autocomplete="off"
        />
        <.textarea
          field={@form[:description]}
          label="Description"
          rows="4"
          placeholder="What you'll do, what to bring, who it's for."
        />
      </div>
    </div>
    """
  end

  attr :form, :map, required: true

  def format_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>Format</h2>
      </div>
      <.event_type_grid field={@form[:event_type]} />
      <.field_errors field={@form[:event_type]} />
    </div>
    """
  end

  attr :form, :map, required: true
  attr :selected_location, :map, required: true
  attr :duration_prompt, :string, default: nil
  attr :date_help, :string, default: nil
  slot :recurring_controls

  def when_panel(assigns) do
    form = assigns.form

    time_zone =
      if form[:event_type].value == :virtual or not is_nil(assigns.selected_location),
        do: form[:time_zone].value

    assigns =
      assigns
      |> assign(:schedule_time_zone, time_zone)
      |> assign(
        :ambiguous_time_label,
        ambiguous_time_label(form[:date].value, form[:start_time].value, time_zone)
      )
      |> assign(:calculated_end_time, end_time_label(form, time_zone))

    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>When</h2>
      </div>
      <div class="form-grid">
        <p :if={@schedule_time_zone} class="form-help" id="huddl-time-zone">
          Times use <strong>{@schedule_time_zone}</strong>.
          <span :if={@ambiguous_time_label}>
            The earlier occurrence will be used: <strong>{@ambiguous_time_label}</strong>.
          </span>
        </p>

        <div class="form-row form-row-inline">
          <div class="form-col-md">
            <.input field={@form[:date]} type="date" label="Date" help={@date_help} />
          </div>
          <div class="form-col-sm">
            <.input field={@form[:start_time]} type="time" label="Start time" />
          </div>
          <div class="form-col-sm">
            <.select
              field={@form[:duration_minutes]}
              label="Duration"
              prompt={@duration_prompt}
              options={duration_options(@form[:duration_minutes].value)}
            />
          </div>
        </div>

        <p :if={@calculated_end_time} class="form-help">
          Ends at: <strong>{@calculated_end_time}</strong>
        </p>

        {render_slot(@recurring_controls)}
      </div>
    </div>
    """
  end

  defp end_time_label(form, time_zone) do
    case Huddlz.TimeZone.resolve_interval(
           form[:date].value,
           form[:start_time].value,
           form[:duration_minutes].value,
           time_zone
         ) do
      {:ok, starts_at, ends_at} -> format_end_time(starts_at, ends_at)
      _ -> nil
    end
  end

  defp format_end_time(starts_at, ends_at) do
    format = if starts_at.zone_abbr == ends_at.zone_abbr, do: "%I:%M %p", else: "%I:%M %p %Z"

    case Date.diff(DateTime.to_date(ends_at), DateTime.to_date(starts_at)) do
      0 -> Calendar.strftime(ends_at, format)
      1 -> Calendar.strftime(ends_at, format <> " (next day)")
      _ -> Calendar.strftime(ends_at, format <> " (%a, %b %-d)")
    end
  end

  defp ambiguous_time_label(%Date{} = date, %Time{} = time, time_zone)
       when is_binary(time_zone) do
    case DateTime.new(date, time, time_zone) do
      {:ambiguous, earlier, _later} ->
        {hours, minutes} = String.split_at(Calendar.strftime(earlier, "%z"), 3)
        "#{earlier.zone_abbr} (UTC#{hours}:#{minutes})"

      _ ->
        nil
    end
  end

  defp ambiguous_time_label(_date, _time, _time_zone), do: nil

  attr :form, :map, required: true
  attr :show_physical_location, :boolean, required: true
  attr :show_virtual_link, :boolean, required: true
  attr :group_locations, :list, required: true
  attr :selected_location, :map, default: nil
  attr :new_location_path, :string, required: true

  def where_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>Where</h2>
      </div>
      <div class="form-grid">
        <%= if @show_physical_location do %>
          <.live_component
            module={HuddlzWeb.Live.SavedLocationPicker}
            id="saved-location-picker"
            group_locations={@group_locations}
            selected_location={@selected_location}
            new_location_path={@new_location_path}
            field={@form[:group_location_id]}
          />
        <% end %>

        <%= if @show_virtual_link do %>
          <.input
            field={@form[:virtual_link]}
            type="text"
            inputmode="url"
            autocomplete="url"
            label="Online link"
            placeholder="https://meet.example.com/..."
            help="Only attendees see this link."
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :is_public, :boolean, required: true

  def capacity_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <h2>Capacity &amp; visibility</h2>
      </div>
      <div class="form-grid">
        <.input
          field={@form[:max_attendees]}
          type="number"
          label="Max attendees"
          placeholder="No limit"
          help="Leave blank for unlimited. When full, new RSVPs go to a waitlist."
        />

        <%= if @is_public do %>
          <div class="form-row">
            <.toggle field={@form[:is_private]} label="Members only" />
            <p class="form-help">
              Only group members can RSVP. Useful for private workshops or socials.
            </p>
          </div>
        <% else %>
          <p class="form-help">
            <.icon name="hero-lock-closed" class="h-4 w-4 inline" />
            This will be a private huddl (private groups can only create private huddlz).
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :live_action, :atom, required: true
  attr :group, :map, required: true
  attr :actor, :map, required: true
  attr :cancel_path, :string, required: true

  def location_modal(assigns) do
    ~H"""
    <.modal
      :if={@live_action == :new_location}
      id="new-location-modal"
      show
      on_cancel={JS.patch(@cancel_path)}
    >
      <h2 id="new-location-modal-title" class="text-xl font-bold tracking-tight mb-6">
        Add New Address
      </h2>

      <.live_component
        module={HuddlzWeb.Live.AddressBookLocationForm}
        id="new-location-form"
        group={@group}
        actor={@actor}
        cancel_path={@cancel_path}
      />
    </.modal>
    """
  end
end
