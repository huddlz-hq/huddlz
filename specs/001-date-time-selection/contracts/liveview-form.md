# LiveView Form Contract

**Component**: HuddlLive.New
**Path**: `/huddlz/new`

## Form Fields Contract

### Date Picker Component
```elixir
<.date_picker field={@form[:date]} label="Date" required />
```
**Properties**:
- `field`: Form field atom
- `label`: Display label
- `required`: Boolean
- `min`: Today's date (enforced)
- `class`: Optional CSS classes

**Behavior**:
- Renders HTML date input
- Blocks past dates
- Shows calendar widget on focus

### Time Picker Component
```elixir
<.time_picker field={@form[:start_time]} label="Start Time" required />
```
**Properties**:
- `field`: Form field atom
- `label`: Display label
- `required`: Boolean
- `step`: 900 (15 minutes in seconds)
- `allow_custom`: true (allows manual entry)
- `class`: Optional CSS classes

**Behavior**:
- Shows dropdown with 15-minute increments
- Allows manual text input
- Validates time format (HH:MM)

### Duration Picker Component
```elixir
<.duration_picker field={@form[:duration_minutes]} label="Duration" required />
```
**Properties**:
- `field`: Form field atom
- `label`: Display label
- `required`: Boolean
- `options`: Preset duration list
- `class`: Optional CSS classes

**Behavior**:
- Dropdown with preset options
- Values in minutes (30, 60, 90, 120, 150, 180, 240, 360)
- Display labels (30 minutes, 1 hour, 1.5 hours, etc.)

## LiveView Events

### validate Event
```elixir
def handle_event("validate", %{"huddl" => huddl_params}, socket)
```
**Params**:
```elixir
%{
  "date" => "2025-09-29",
  "start_time" => "14:30",
  "duration_minutes" => "120",
  # ... other fields
}
```
**Response**:
- Updates form with validation errors
- Recalculates and displays end time
- Real-time feedback

### save Event
```elixir
def handle_event("save", %{"huddl" => huddl_params}, socket)
```
**Params**: Same as validate
**Response**:
- Success: Redirect to huddl view page
- Failure: Display errors on form

## Calculated Fields Display

### End Time Display
```heex
<div class="text-sm text-gray-600">
  Ends at: <%= format_end_time(@form[:date].value, @form[:start_time].value, @form[:duration_minutes].value) %>
</div>
```

**Calculation**:
```elixir
def format_end_time(date, start_time, duration_minutes) do
  # Combine date + start_time
  # Add duration_minutes
  # Format for display
end
```

## Validation Messages

### Client-Side (HTML5)
- Date: "Please select a date"
- Time: "Please enter a valid time"
- Duration: "Please select a duration"

### Server-Side (Ash)
- Date: "Date must be today or in the future"
- Time: "Invalid time format"
- Duration: "Duration must be between 15 minutes and 24 hours"
- End time: "Event cannot span multiple days" (if applicable)

## Form State Management

### Initial State
```elixir
%{
  date: Date.utc_today(),
  start_time: next_quarter_hour(),
  duration_minutes: 60,
  # ... other fields with defaults
}
```

### State Updates
1. User changes any datetime field
2. LiveView validates on change
3. End time recalculated and displayed
4. Validation errors shown immediately

## Error States

### Field-Level Errors
```heex
<.error :for={msg <- @form[:date].errors}>{msg}</.error>
```

### Form-Level Errors
```heex
<.error :if={@form.errors[:base]}>
  <%= @form.errors[:base] %>
</.error>
```

## Accessibility

### ARIA Labels
- Date picker: `aria-label="Select event date"`
- Time picker: `aria-label="Select start time"`
- Duration: `aria-label="Select event duration"`

### Keyboard Navigation
- Tab through fields
- Arrow keys in dropdowns
- Enter to select
- Escape to close pickers

## Mobile Responsiveness

### Layout
```heex
<div class="grid gap-4 sm:grid-cols-3">
  <!-- Date, Time, Duration in row on desktop -->
  <!-- Stacked on mobile -->
</div>
```

### Touch Targets
- Minimum 44x44px touch areas
- Clear spacing between inputs
- Native mobile pickers when available