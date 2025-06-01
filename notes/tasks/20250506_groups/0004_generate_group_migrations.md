# Task: Generate Group Migrations

## Context
- Part of feature: Group Management
- Sequence: Task 4 of 8
- Purpose: Create database migrations for the Group and GroupMember resources

## Task Boundaries
- In scope:
  - Generate migrations for the groups table using Ash migrations
  - Generate migrations for the group_members table
  - Run the migrations
- Out of scope:
  - Modifying the resource definitions after migration generation
  - Seed data creation

## Current Status
- Progress: 100%
- Blockers: None
- Current activity: Completed

## Requirements Analysis
- Use Ash Postgres migration tooling for resources
- Create snapshot of resources before generating migrations
- Generate migrations that include all relationships and constraints
- Maintain data integrity with appropriate indexes

## Implementation Plan
- First, ensure resources are registered in the domain
- Create resource snapshots using ash_postgres.generate_snapshot
- Generate migrations using ash_postgres.generate_migrations
- Review generated migrations for correctness
- Run the migrations to create the tables

## Implementation Checklist
1. Register resources in the Communities domain
2. Generate snapshots of the new resources
3. Generate migrations from the resource snapshots
4. Review generated migrations to ensure correctness
5. Run the migrations
6. Verify the new tables in the database

## Related Files
- lib/huddlz/communities.ex (to update with resource registration)
- priv/resource_snapshots/repo/communities/[timestamp].json (to be generated)
- priv/repo/migrations/[timestamp]_create_groups_and_members.exs (to be generated)

## Commands

### Generate Resource Snapshots
```bash
mix ash_postgres.generate_snapshot Huddlz.Communities.Group
mix ash_postgres.generate_snapshot Huddlz.Communities.GroupMember
```

### Generate Migrations
```bash
mix ash_postgres.generate_migrations --name create_groups_and_members
```

### Run Migrations
```bash
mix ash_postgres.migrate
```

## Definition of Done
- Resource snapshots are generated
- Migration files are created based on the snapshots
- Tables are created in the database with proper structure
- All fields, indexes, and constraints match the resource definitions

## Quality Assurance

### AI Verification (Throughout Implementation)
- Check that resource snapshots match resource definitions
- Verify that migration files properly represent the resources
- Ensure proper indexing for performance

### Human Verification (Required Before Next Task)
- After completing the migration, ask the user:
  "I've generated and run the migrations for the Group and GroupMember resources. Could you please verify the database structure by:
   1. Checking the resource snapshots
   2. Reviewing the migration files
   3. Connecting to the database to inspect the tables
   If everything looks good, I'll proceed to the next task."

## Progress Tracking
1. Register resources in Communities domain - ✅ [Already completed]
2. Generate snapshots of the new resources - ✅ [May 17, 2025]
3. Generate migrations from the resource snapshots - ✅ [May 17, 2025]
4. Review generated migrations to ensure correctness - ✅ [May 17, 2025]
5. Run the migrations - ✅ [May 17, 2025]
6. Verify the new tables in the database - ✅ [May 22, 2025]

## Session Log
- [May 22, 2025] Starting implementation of this task...
- [May 22, 2025] Discovered that migrations were already generated on May 17, 2025
- [May 22, 2025] Found existing migrations: 20250517173417_add_groups_and_group_members.exs
- [May 22, 2025] Found additional migration: 20250522224317_change_group_name_and_description_to_ci_string.exs
- [May 22, 2025] Verified resource snapshots exist for groups and group_members
- [May 22, 2025] Confirmed all migrations are up to date
- [May 22, 2025] Task was already completed previously

## Next Task
- Next task: 0005_move_huddl_to_communities_domain
- Only proceed to the next task after this task is complete and verified