# Task 2: Generate and Run Database Migration

## Objective
Create and apply database migration for password authentication fields.

## Checklist

- [ ] Generate Ash migration using mix ash.codegen
- [ ] Review generated migration for hashed_password column
- [ ] Run migration with mix ash.migrate
- [ ] Verify database schema includes new field
- [ ] Confirm existing user records are unaffected

## Implementation Details

1. Generate migration:
   ```bash
   mix ash.codegen add_password_authentication
   ```

2. Review migration file should include:
   - Add hashed_password column (text/string, nullable)
   - Any indexes needed for password reset tokens

3. Apply migration:
   ```bash
   mix ash.migrate
   ```

4. Verify with:
   ```bash
   mix ash.database_schema
   ```

## Success Criteria

- Migration generates without errors
- Migration runs successfully
- Existing user data remains intact
- New hashed_password column exists in users table
- Database schema matches User resource definition