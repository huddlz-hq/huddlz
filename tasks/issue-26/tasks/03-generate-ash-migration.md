# Task 3: Generate Ash Migration

## Objective
Generate and run the Ash migration to add slug field to the database.

## Steps

1. **Generate Migration**
   ```bash
   mix ash.codegen add_slug_to_groups
   ```

2. **Review Generated Migration**
   - Check the migration file in `priv/repo/migrations/`
   - Ensure it adds slug column with proper constraints
   - Verify unique index is created

3. **Run Migration**
   ```bash
   mix ash.migrate
   ```

4. **Verify Database**
   - Check that groups table has slug column
   - Verify unique index exists
   - Test in iex console if needed

## Expected Migration Content
Should include:
- Add slug column (string, not null)
- Create unique index on slug
- Any additional Ash-generated constraints

## Acceptance Criteria
- [ ] Migration generated successfully
- [ ] Migration file looks correct
- [ ] Migration runs without errors
- [ ] Database schema updated
- [ ] Unique constraint in place

## Notes
- Since we're not in production, no data migration needed
- Ash handles most of the migration complexity
- The unique identity in the resource will generate the appropriate constraints