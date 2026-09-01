defmodule HuddlzWeb.Components.HuddlForm do
  @moduledoc """
  Presentation primitives shared by the huddl create and edit forms:
  the huddl-format radio cards and the duration select options.

  ```
  <.event_type_grid field={@form[:event_type]} />
  <.field_errors field={@form[:event_type]} />

  <.input type="select" options={duration_options()} ... />
  ```
  """
  use Phoenix.Component

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

  attr :resolution, :any, default: nil
  attr :occurrence_field, Phoenix.HTML.FormField, required: true

  def daylight_saving_resolution(%{resolution: %{kind: :gap}} = assigns) do
    assigns =
      assigns
      |> assign(:requested_time, Calendar.strftime(assigns.resolution.requested, "%-I:%M %p"))
      |> assign(:resolved_time, schedule_label(assigns.resolution.selected))
      |> assign(:city, time_zone_city(assigns.resolution.time_zone))

    ~H"""
    <div id="daylight-saving-resolution" data-resolution="gap" class="form-help" role="status">
      {@requested_time} does not exist in {@city}. It will be scheduled at {@resolved_time}.
    </div>
    """
  end

  def daylight_saving_resolution(%{resolution: %{kind: :ambiguous}} = assigns) do
    ~H"""
    <fieldset id="daylight-saving-resolution" data-resolution="ambiguous" class="form-row">
      <legend class="form-label">Choose which local time you mean</legend>
      <div class="form-grid">
        <label for="ambiguous-time-earlier">
          <input
            id="ambiguous-time-earlier"
            type="radio"
            name={@occurrence_field.name}
            value="earlier"
            checked={to_string(@occurrence_field.value) != "later"}
          />
          {schedule_label(@resolution.earlier)} (earlier)
        </label>
        <label for="ambiguous-time-later">
          <input
            id="ambiguous-time-later"
            type="radio"
            name={@occurrence_field.name}
            value="later"
            checked={to_string(@occurrence_field.value) == "later"}
          />
          {schedule_label(@resolution.later)} (later)
        </label>
      </div>
    </fieldset>
    """
  end

  def daylight_saving_resolution(assigns), do: ~H""

  defp schedule_label(datetime), do: Calendar.strftime(datetime, "%-I:%M %p %Z")

  defp time_zone_city(time_zone) do
    time_zone
    |> String.split("/")
    |> List.last()
    |> String.replace("_", " ")
  end

  attr :time_zone, :string, default: nil
  attr :error, :string, default: nil
  attr :options, :list, required: true

  def venue_time_zone_field(assigns) do
    ~H"""
    <%= if @error do %>
      <HuddlzWeb.Components.Input.searchable_select
        id="venue-time-zone"
        name="location_time_zone"
        label="huddl time zone"
        value={@time_zone}
        options={@options}
        errors={[@error]}
      />
    <% else %>
      <div class="form-row">
        <span class="form-label">huddl time zone</span>
        <p id="venue-time-zone-derived" class="form-help">
          {Huddlz.TimeZone.friendly_label(@time_zone)}
        </p>
      </div>
    <% end %>
    """
  end
end
