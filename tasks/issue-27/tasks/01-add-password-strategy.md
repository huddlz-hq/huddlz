# Task 1: Add Password Strategy to User Resource

## Objective
Update the User resource to support password authentication alongside magic links.

## Checklist

- [ ] Add password strategy to authentication block in User resource
- [ ] Add hashed_password attribute with proper security settings
- [ ] Configure register_with_password action
- [ ] Configure sign_in_with_password action
- [ ] Configure reset_password request/confirm actions
- [ ] Verify password change actions are configured
- [ ] Test that existing magic link functionality still works
- [ ] Verify existing users without passwords can still sign in

## Implementation Details

1. Update `lib/huddlz/accounts/user.ex`:
   - Add password strategy to authentication extension
   - Add hashed_password attribute (type: :string, sensitive: true)
   - Configure password-related actions

2. Verify authentication configuration includes:
   - Password strategy with reasonable defaults
   - Reset password token strategy
   - Proper sender configuration for reset emails

3. Test considerations:
   - Existing user can still use magic links
   - New actions are properly defined
   - No breaking changes to current auth flow

## Success Criteria

- User resource compiles without errors
- Both strategies are configured in authentication block
- Password actions are available but optional
- Existing magic link tests still pass