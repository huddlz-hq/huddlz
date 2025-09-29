# Research Findings: Date Time Selection

**Date**: 2025-09-29
**Feature**: Date Time Selection for Huddl Creation

## Current Implementation Analysis

### Database Schema
- **Current Fields**: `starts_at` (utc_datetime), `ends_at` (utc_datetime)
- **Storage**: UTC timezone, not null constraints
- **Migration Path**: Will keep existing columns, calculate ends_at from starts_at + duration

### Ash Resource Structure
```elixir
# Current attributes
attribute :starts_at, :utc_datetime, allow_nil?: false
attribute :ends_at, :utc_datetime, allow_nil?: false
```

### LiveView Form
- Uses HTML5 `datetime-local` inputs
- No custom JavaScript or enhanced UI components
- Basic browser-native datetime picking

## Technical Decisions

### 1. DateTime Field Strategy
**Decision**: Keep existing `starts_at` and `ends_at` database fields
**Rationale**:
- Maintains backward compatibility with existing data
- Avoids complex migration of existing records
- Allows efficient database queries on time ranges
**Alternatives Considered**:
- Storing duration as separate field: Rejected due to denormalization concerns
- Single datetime with duration: Would require migration of all existing records

### 2. Duration Calculation Approach
**Decision**: Calculate `ends_at` from `starts_at` + duration on form submission
**Rationale**:
- Maintains data integrity in database
- Simplifies queries and existing business logic
- No changes needed to existing Ash actions
**Alternatives Considered**:
- Store duration field: Would duplicate data
- Virtual attributes only: Could cause inconsistencies

### 3. Component Architecture
**Decision**: Create custom Phoenix components for date, time, and duration pickers
**Rationale**:
- Leverage existing `core_components.ex` patterns
- Maintain consistency with current UI/UX
- Server-side rendering aligns with LiveView patterns
**Alternatives Considered**:
- JavaScript date picker library: Adds complexity and dependencies
- Alpine.js components: Unnecessary for this use case

### 4. Time Input Implementation
**Decision**: HTML select with 15-minute increments + text input fallback
**Rationale**:
- Simple implementation without JavaScript
- Accessible and mobile-friendly
- Allows precise time entry when needed
**Alternatives Considered**:
- Custom time picker widget: Over-engineering for the requirement
- Text-only input: Poor UX for common time selections

### 5. Duration Options
**Decision**: Predefined select with options: 30m, 1h, 1.5h, 2h, 2.5h, 3h, 4h, 6h
**Rationale**:
- Covers most common meeting durations
- Simple select element, no complex UI needed
- Clear and predictable for users
**Alternatives Considered**:
- Free-form duration input: Too many edge cases
- Slider component: Harder to select precise values

### 6. Validation Strategy
**Decision**: Server-side validation in Ash changeset with client-side HTML5 validation
**Rationale**:
- Leverages existing Ash validation patterns
- HTML5 validation provides immediate feedback
- No additional JavaScript required
**Alternatives Considered**:
- JavaScript validation library: Unnecessary complexity
- LiveView real-time validation: Could cause performance issues

### 7. Timezone Handling
**Decision**: Keep UTC storage, display in user's local timezone (future enhancement)
**Rationale**:
- Current implementation already uses UTC
- Timezone conversion can be added incrementally
- Maintains data consistency
**Alternatives Considered**:
- Store timezone with event: Complex for this feature scope
- Browser timezone detection: Better as separate feature

## Phoenix LiveView Patterns

### Form Field Binding
```elixir
# Use Phoenix.HTML helpers for form fields
# Leverage existing AshPhoenix.Form integration
# Maintain two-way data binding through LiveView socket
```

### Component Structure
```elixir
# Extend core_components.ex with:
# - date_picker/1
# - time_picker/1
# - duration_picker/1
```

### Event Handling
```elixir
# Handle in existing handle_event callbacks
# "validate" -> Update form and recalculate ends_at
# "save" -> Submit with calculated ends_at
```

## Testing Strategy

### Unit Tests
- Ash changeset validation for duration limits
- Date/time calculation logic
- Component rendering tests

### Integration Tests
- Form submission with various duration combinations
- Validation error scenarios
- Existing permission matrix maintained

### BDD Tests
- Update existing Cucumber scenarios
- Add scenarios for new input method
- Verify calculated end times

## Migration Safety

### No Breaking Changes
- Existing data remains valid
- API contracts unchanged
- Database schema stable

### Rollback Plan
- Feature flag for new UI (if needed)
- Revert to datetime-local inputs
- No data migration required

## Performance Considerations

### Client-Side
- No additional JavaScript libraries
- Minimal DOM manipulation
- Leverages browser-native inputs where possible

### Server-Side
- Simple calculation (addition operation)
- No additional database queries
- Existing indexes sufficient

## Resolved Clarifications

All technical clarifications have been resolved:
- ✅ Database storage approach determined
- ✅ Component architecture decided
- ✅ Validation strategy defined
- ✅ Testing approach outlined
- ✅ Migration safety confirmed

## Next Steps

Ready to proceed with Phase 1 (Design & Contracts) to:
1. Define updated Ash resource attributes
2. Design component interfaces
3. Create API contracts for form submission
4. Generate test specifications