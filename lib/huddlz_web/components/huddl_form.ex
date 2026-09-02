defmodule HuddlzWeb.Components.HuddlForm do
  @moduledoc """
  Presentation primitives shared by the huddl create and edit forms:
  the huddl-format radio cards, the duration select options, and the
  basics/format/when/where/capacity panels and location modal.

  ```
  <.basics_panel form={@form} />
  <.format_panel form={@form} />
  <.when_panel form={@form} calculated_end_time={@calculated_end_time}>
    <:recurring_controls>...</:recurring_controls>
  </.when_panel>
  <.where_panel form={@form} show_physical_location={@show_physical_location}
    show_virtual_link={@show_virtual_link} group_locations={@group_locations}
    selected_location={@selected_location} new_location_path={~p"..."} />
  <.capacity_panel form={@form} is_public={@group.is_public} />

  <.location_modal live_action={@live_action} cancel_path={~p"..."}
    modal_location_address={@modal_location_address}
    modal_location_name={@modal_location_name} />
  ```
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Button, only: [button: 1]
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
  attr :calculated_end_time, :string, default: nil
  attr :duration_prompt, :string, default: nil
  attr :schedule_time_zone, :string, default: nil
  attr :ambiguous_time_label, :string, default: nil
  slot :recurring_controls

  def when_panel(assigns) do
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
            <.input field={@form[:date]} type="date" label="Date" />
          </div>
          <div class="form-col-sm">
            <.input field={@form[:start_time]} type="time" label="Start time" />
          </div>
          <div class="form-col-sm">
            <.select
              field={@form[:duration_minutes]}
              label="Duration"
              prompt={@duration_prompt}
              options={duration_options()}
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
            field={@form[:physical_location]}
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
  attr :modal_location_address, :string, default: nil
  attr :modal_location_name, :string, default: nil
  attr :cancel_path, :string, required: true

  def location_modal(assigns) do
    ~H"""
    <.modal
      :if={@live_action == :new_location}
      id="new-location-modal"
      show
      on_cancel={JS.patch(@cancel_path)}
    >
      <h2 class="font-display text-xl tracking-tight text-glow mb-6">Add New Address</h2>

      <form phx-submit="save_location" phx-change="modal_form_changed" class="form-grid">
        <div class="form-row">
          <label class="form-label" for="modal-address-autocomplete-input">
            Search for an address
          </label>
          <.live_component
            module={HuddlzWeb.Live.LocationAutocomplete}
            id="modal-address-autocomplete"
            variant={:form}
            placeholder="Search for an address or venue..."
            types={[]}
            fetch_coordinates={true}
            show_clear={true}
          />
        </div>

        <div class="form-row">
          <label class="form-label" for="location-name-input">
            Location name (optional)
          </label>
          <input
            type="text"
            id="location-name-input"
            name="location_name"
            value={@modal_location_name}
            phx-debounce="100"
            placeholder="e.g., Community Center"
            class="form-input"
          />
        </div>

        <div class="form-foot is-flush">
          <.button variant={:primary} type="submit" disabled={is_nil(@modal_location_address)}>
            Save address
          </.button>
          <.button variant={:secondary} patch={@cancel_path}>
            Cancel
          </.button>
        </div>
      </form>
    </.modal>
    """
  end
end
