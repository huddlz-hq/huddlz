defmodule HuddlzWeb.Components.HuddlForm do
  @moduledoc """
  Presentation primitives shared by the huddl create and edit forms:
  the event-type radio cards and the duration select options.

  ```
  <.event_type_grid field={@form[:event_type]} />
  <.field_errors field={@form[:event_type]} />

  <.input type="select" options={duration_options()} ... />
  ```

  `event_type_option/1` is also exported so a form that needs a divergent
  layout can assemble its own grid without forking the wrapper.
  """
  use Phoenix.Component

  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :title, :string, required: true
  attr :desc, :string, required: true
  slot :icon, required: true

  def event_type_option(assigns) do
    radio_id = "event-type-#{assigns.value}"
    assigns = assign(assigns, :radio_id, radio_id)

    ~H"""
    <label for={@radio_id} class="sr-only">{@title}</label>
    <label
      for={@radio_id}
      class={["event-type-option", to_string(@field.value) == @value && "is-active"]}
    >
      <input
        id={@radio_id}
        type="radio"
        name={@field.name}
        value={@value}
        checked={to_string(@field.value) == @value}
      />
      <div class="event-type-icon">{render_slot(@icon)}</div>
      <div>
        <div class="event-type-title">{@title}</div>
        <div class="event-type-desc">{@desc}</div>
      </div>
    </label>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  def event_type_grid(assigns) do
    ~H"""
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
    """
  end

  def duration_options do
    [
      {"30 minutes", "30"},
      {"1 hour", "60"},
      {"1.5 hours", "90"},
      {"2 hours", "120"},
      {"2.5 hours", "150"},
      {"3 hours", "180"},
      {"4 hours", "240"},
      {"6 hours", "360"}
    ]
  end
end
