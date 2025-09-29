# Data Model: Date Time Selection

**Date**: 2025-09-29
**Feature**: Date Time Selection for Huddl Creation

## Entity Updates

### Huddl Resource Modifications

#### Existing Attributes (No Changes)
```elixir
attribute :starts_at, :utc_datetime do
  allow_nil? false
end

attribute :ends_at, :utc_datetime do
  allow_nil? false
end
```

#### Form-Only Arguments (Virtual Attributes)
These are used only during form submission and not persisted:

```elixir
# In the create/update actions
argument :date, :date do
  allow_nil? false
  description "The date of the huddl"
end

argument :start_time, :time do
  allow_nil? false
  description "The start time of the huddl"
end

argument :duration_minutes, :integer do
  allow_nil? false
  description "Duration in minutes (minimum 15, maximum 1440)"
  constraints min: 15, max: 1440
end
```

## Validation Rules

### Date Validation
- **Future dates only**: Date must be today or later
- **Maximum advance booking**: Optional, not specified in requirements

### Time Validation
- **Valid time format**: HH:MM in 24-hour or 12-hour format with AM/PM
- **15-minute increment suggestion**: UI guidance, not enforced in validation
- **Manual entry allowed**: Any valid time accepted

### Duration Validation
- **Minimum**: 15 minutes
- **Maximum**: 1440 minutes (24 hours)
- **Allowed values**: While UI shows presets, any value within range accepted

### Calculated Fields
```elixir
# In changeset/action
starts_at = DateTime.new!(date, start_time, timezone)
ends_at = DateTime.add(starts_at, duration_minutes, :minute)
```

## State Transitions

### Form Input State
1. **Initial State**: Empty form with today's date, current time rounded to next 15 minutes
2. **User Selection**: Date picked, time selected/entered, duration chosen
3. **Validation**: Client-side HTML5 + server-side Ash validation
4. **Calculation**: Combine date + time → starts_at, add duration → ends_at
5. **Submission**: Send starts_at and ends_at to Ash action

### Data Flow
```
User Input          →  Virtual Arguments  →  Calculated Values  →  Persisted
date: 2025-09-29      date                  starts_at:            starts_at
time: 11:30 AM    →   start_time        →   2025-09-29T11:30    → (stored)
duration: 2h          duration_minutes      ends_at:              ends_at
                      (120)                 2025-09-29T13:30    → (stored)
```

## Relationships (Unchanged)

### Existing Relationships Maintained
- `belongs_to :group` - The community group hosting the huddl
- `belongs_to :created_by` - User who created the huddl
- `has_many :rsvps` - Event attendees
- `has_many :attendees` through RSVPs

## Attributes Summary

### Input Attributes (Form Only)
| Attribute | Type | Constraints | Description |
|-----------|------|------------|-------------|
| date | date | >= today | Event date |
| start_time | time | valid time | Event start time |
| duration_minutes | integer | 15-1440 | Duration in minutes |

### Persisted Attributes (Unchanged)
| Attribute | Type | Constraints | Description |
|-----------|------|------------|-------------|
| starts_at | utc_datetime | not null, future (on create) | Event start |
| ends_at | utc_datetime | not null, > starts_at | Event end |

### Preset Duration Options
For UI display only, not enforced in model:
- 30 minutes
- 1 hour (60 minutes)
- 1.5 hours (90 minutes)
- 2 hours (120 minutes)
- 2.5 hours (150 minutes)
- 3 hours (180 minutes)
- 4 hours (240 minutes)
- 6 hours (360 minutes)

## Migration Requirements

**No database migration required** - Using existing starts_at and ends_at fields.

The only changes are:
1. How form inputs are collected (UI layer)
2. How starts_at and ends_at are calculated (changeset logic)
3. Validation rules remain the same

## API Impact

### Create/Update Action Changes
```elixir
# Before (current implementation)
create :create do
  accept [:starts_at, :ends_at, ...]
end

# After (with new UI)
create :create do
  argument :date, :date, allow_nil?: false
  argument :start_time, :time, allow_nil?: false
  argument :duration_minutes, :integer, allow_nil?: false

  # Calculate starts_at and ends_at in change
  change fn changeset, _ ->
    # Combine date + time + duration to set starts_at and ends_at
  end
end
```

### Backward Compatibility
- Existing API endpoints accepting starts_at/ends_at directly still work
- New form uses virtual arguments that calculate the same fields
- No breaking changes to API contracts