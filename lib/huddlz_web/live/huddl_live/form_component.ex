defmodule HuddlzWeb.HuddlLive.FormComponent do
  @moduledoc """
  Shared form fields component for huddl create/edit forms.
  Uses slots for sections that differ between create and edit.
  """
  use Phoenix.Component

  import HuddlzWeb.CoreComponents

  attr :form, :any, required: true
  attr :show_physical_location, :boolean, default: true
  attr :show_virtual_link, :boolean, default: false
  attr :calculated_end_time, :string, default: nil
  attr :address_suggestions, :list, default: []
  attr :show_address_suggestions, :boolean, default: false
  attr :address_loading, :boolean, default: false
  attr :address_error, :string, default: nil
  attr :is_public, :boolean, required: true
  slot :image_section, required: true
  slot :recurring_section, required: true
  slot :actions, required: true

  def huddl_form_fields(assigns) do
    ~H"""
    <.input field={@form[:title]} type="text" label="Title" required />
    <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

    {render_slot(@image_section)}

    <div class="grid gap-4 sm:grid-cols-2">
      <.date_picker field={@form[:date]} label="Date" />
      <.time_picker field={@form[:start_time]} label="Start Time" />
    </div>

    <.duration_picker field={@form[:duration_minutes]} label="Duration" />

    <%= if @calculated_end_time do %>
      <div class="border border-primary/20 p-3 bg-primary/5 flex items-center gap-2 text-sm">
        <.icon name="hero-clock" class="h-5 w-5" />
        <span>Ends at: {@calculated_end_time}</span>
      </div>
    <% end %>

    {render_slot(@recurring_section)}

    <.input
      field={@form[:event_type]}
      type="select"
      label="Event Type"
      options={[
        {"In-Person", "in_person"},
        {"Virtual", "virtual"},
        {"Hybrid (Both In-Person and Virtual)", "hybrid"}
      ]}
      required
    />

    <%= if @show_physical_location do %>
      <.location_autocomplete
        id="address-autocomplete"
        name="form[physical_location]"
        value={AshPhoenix.Form.value(@form.source, :physical_location) || ""}
        label="Physical Location"
        placeholder="Search for an address or venue..."
        suggestions={@address_suggestions}
        show_suggestions={@show_address_suggestions}
        loading={@address_loading}
        error={@address_error}
      />
    <% end %>

    <%= if @show_virtual_link do %>
      <.input
        field={@form[:virtual_link]}
        type="text"
        label="Virtual Meeting Link"
        placeholder="e.g., https://zoom.us/j/123456789"
      />
    <% end %>

    <%= if @is_public do %>
      <.input
        field={@form[:is_private]}
        type="checkbox"
        label="Make this a private event (only visible to group members)"
      />
    <% else %>
      <p class="text-sm text-base-content/60">
        <.icon name="hero-lock-closed" class="h-4 w-4 inline" />
        This will be a private event (private groups can only create private events)
      </p>
    <% end %>

    {render_slot(@actions)}
    """
  end
end
