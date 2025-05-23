# Task: Move Huddl to Communities Domain

## Context
- Part of feature: Group Management
- Sequence: Task 5 of 8
- Purpose: Move the Huddl resource from Huddls domain to Communities domain

## Task Boundaries
- In scope: 
  - Update the Huddl resource to belong to the Communities domain
  - Modify the Huddls domain to remove the resource
  - Update the Communities domain to include the Huddl resource
- Out of scope: 
  - Changing Huddl functionality or structure
  - Creating new migrations for Huddl
  - Modifying relationships between Huddl and other resources

## Current Status
- Progress: 100%
- Blockers: None
- Current activity: Completed

## Requirements Analysis
- Move the Huddl resource from Huddls domain to Communities domain
- Update all references to the resource location
- Maintain all existing functionality
- No database changes required as only the code organization changes

## Implementation Plan
- Update the Huddl module to reference the Communities domain
- Remove the Huddl resource from the Huddls domain
- Add the Huddl resource to the Communities domain
- Update any import statements that reference the old path

## Implementation Checklist
1. Update the Huddl resource module to use Communities domain
2. Remove Huddl references from the Huddls domain
3. Add Huddl to the Communities domain resources
4. Update any import statements in controllers or other modules
5. Verify that existing functionality still works

## Related Files
- lib/huddlz/huddls/huddl.ex (to update domain reference)
- lib/huddlz/huddls.ex (to remove Huddl resource)
- lib/huddlz/communities.ex (to add Huddl resource)
- Any files importing or referencing Huddls.Huddl

## Code Examples

### Updated Huddl Module
```elixir
defmodule Huddlz.Communities.Huddl do
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,  # Changed from Huddlz.Huddls
    data_layer: AshPostgres.DataLayer

  # Rest of the module remains the same
end
```

### Updated Communities Domain
```elixir
defmodule Huddlz.Communities do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Communities.Group
    resource Huddlz.Communities.GroupMember
    resource Huddlz.Communities.Huddl do
      define :get_upcoming, action: :upcoming
      define :search, action: :search, args: [:query]
      define :get_by_status, action: :by_status, args: [:status]
    end
  end
end
```

### Updated Huddls Domain (if kept)
```elixir
defmodule Huddlz.Huddls do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    # Huddl resource moved to Communities domain
  end
end
```

## Definition of Done
- Huddl resource successfully moved to Communities domain
- All references updated to the new module location
- No functionality changes or regressions
- All tests pass with the new structure

## Quality Assurance

### AI Verification (Throughout Implementation)
- Check for all references to the old path and update them
- Verify that the moved resource maintains all of its previous functionality
- Run unit and integration tests to ensure no regression

### Human Verification (Required Before Next Task)
- After completing the move, ask the user:
  "I've moved the Huddl resource to the Communities domain. Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Testing huddl-related functionality
   If everything looks good, I'll proceed to the next task."

## Progress Tracking
1. Update the Huddl resource module to use Communities domain - ✅ [May 16, 2025]
2. Remove Huddl references from the Huddls domain - ✅ [May 16, 2025]
3. Add Huddl to the Communities domain resources - ✅ [May 16, 2025]
4. Update any import statements in controllers or other modules - ✅ [May 16, 2025]
5. Verify that existing functionality still works - ✅ [May 16, 2025]

## Session Log
- [May 22, 2025] Discovered this task was already completed
- [May 22, 2025] Verified Huddl resource is at lib/huddlz/communities/huddl.ex
- [May 22, 2025] Confirmed it uses domain: Huddlz.Communities
- [May 22, 2025] Confirmed Huddls domain no longer exists
- [May 22, 2025] Task was completed on May 16, 2025

## Next Task
- Next task: 0006_create_admin_panel
- Only proceed to the next task after this task is complete and verified