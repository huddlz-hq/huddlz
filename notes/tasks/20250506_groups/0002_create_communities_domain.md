# Task: Create Communities Domain

## Context
- Part of feature: Group Management
- Sequence: Task 2 of 8
- Purpose: Create a new domain to house both Groups and Huddls

## Task Boundaries
- In scope: 
  - Create new Communities domain structure
  - Set up domain configuration
- Out of scope: 
  - Moving Huddl resource (separate task)
  - Creating Group resource (separate task)

## Current Status
- Progress: 0%
- Blockers: None
- Next steps: Begin implementation

## Requirements Analysis
- Create a new domain called Huddlz.Communities
- Configure the domain to use the proper OTP app and settings
- Prepare the domain to house both Group and Huddl resources

## Implementation Plan
- Create a new domain module at lib/huddlz/communities.ex
- Configure the domain with proper use statements and OTP app
- Set up the resources section to be ready for the Group and Huddl resources

## Implementation Checklist
1. Create the Communities domain module file
2. Set up Ash.Domain with proper configuration
3. Prepare resources section (initially empty)
4. Update application configuration to include the new domain

## Related Files
- lib/huddlz/communities.ex (to be created)
- config/config.exs (to update)

## Code Examples

### Communities Domain Module
```elixir
defmodule Huddlz.Communities do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    # Group and Huddl resources will be added here
  end
end
```

### Config Update
```elixir
config :huddlz,
  ash_domains: [
    Huddlz.Accounts,
    Huddlz.Huddls,
    Huddlz.Communities  # Add the new domain
  ]
```

## Definition of Done
- Communities domain module is created
- Configuration is updated to include the new domain
- Module compiles successfully
- All tests pass

## Progress Tracking
- Update after completing each checklist item
- Mark items as completed with timestamps
- Document any issues encountered and how they were resolved

## Next Task
- Next task: 0003_create_group_resource
- Only proceed to the next task after this task is complete and verified