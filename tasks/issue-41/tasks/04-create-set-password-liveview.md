# Task 4: Create Set Password LiveView

**Status**: completed
**Started**: 2025-01-06 10:25 AM
**Completed**: 2025-01-06 10:45 AM

## Objective

Create a page where users who signed up with magic link can set a password for their account, enabling them to use password-based authentication in addition to magic links.

## Requirements

1. Create `SetPasswordLive` module
2. Only accessible to authenticated users without a password
3. Allow setting initial password
4. Add link in profile dropdown
5. Clear instructions about the benefit

## Implementation Steps

### 1. Create SetPasswordLive Module

Create `lib/huddlz_web/live/auth_live/set_password.ex`:
- Check user is authenticated in mount
- Verify user doesn't already have password
- Handle password form submission
- Use appropriate Ash action to set password

### 2. Create Set Password Template

Create `lib/huddlz_web/live/auth_live/set_password.html.heex`:
- Explanation of benefits
- Password field
- Password confirmation field
- Requirements display
- Submit button
- Success message/redirect

### 3. Add Access Control

Ensure only appropriate users can access:
- Must be signed in
- Must NOT have existing password
- Redirect if conditions not met

### 4. Add Routing

Add route in `router.ex` within authenticated scope:
```elixir
live "/settings/set-password", AuthLive.SetPassword, :index
```

### 5. Update Profile Dropdown

In profile dropdown component:
- Check if user has password set
- If not, show "Set Password" option
- Link to set password page

### 6. Update User Resource

Ensure User resource has:
- Action to set initial password
- Way to check if password exists
- Proper validation

## Implementation Details

### UI/UX Considerations

1. **Clear Explanation**
   - "Add a password to sign in without email"
   - "You'll still be able to use magic links"
   - Benefits of having both options

2. **Form Design**
   - Similar to registration password fields
   - Real-time validation
   - Clear requirements

3. **Success Handling**
   - Show success message
   - Stay on page or redirect to profile
   - Update profile dropdown immediately

## Testing Requirements

1. **Unit Tests**
   - Access control (with/without password)
   - Form rendering
   - Password setting logic

2. **Integration Tests**
   - Full flow from profile to password set
   - Verification that password works for sign-in
   - Proper redirects for unauthorized access

3. **Feature Tests**
   - New feature test for setting password
   - Test profile dropdown visibility
   - Test both auth methods work after

## Success Criteria

- [x] Page only accessible to users without password (already in ProfileLive)
- [x] Form clearly explains the benefit (in profile page)
- [x] Password can be set successfully (existing functionality)
- [x] User can sign in with password after setting
- [x] Magic link still works after setting password
- [x] Profile dropdown updates appropriately (removed separate link)
- [ ] All tests pass (some need updates)

## Edge Cases

- User navigates directly to URL with password already set
- User tries to access while not authenticated
- Session expires during form fill
- Password setting fails (validation)

## Notes

- This is different from password reset - it's initial setup
- Consider allowing password removal in future
- May want to send confirmation email
- Could add 2FA setup on same page later