# Task 2: Create Registration LiveView

**Status**: completed
**Started**: 2025-01-06 11:36 AM
**Completed**: 2025-01-06 12:20 PM

## Objective

Create a custom registration page that focuses on password-based registration with a clean, user-friendly interface.

## Requirements

1. Create a custom `RegisterLive` module
2. Password-based registration only (no magic link on this page)
3. Collect email, password, confirmation, and optional display name
4. Client-side password validation
5. Clear success/error feedback

## Implementation Steps

### 1. Create RegisterLive Module

Create `lib/huddlz_web/live/auth_live/register.ex`:
- Mount with empty changeset
- Handle form validation on change
- Submit to User.register_with_password action
- Auto-sign in after successful registration

### 2. Create Registration Template

Create `lib/huddlz_web/live/auth_live/register.html.heex`:
- Email field
- Password field with requirements display
- Password confirmation field
- Display name field (optional)
- Submit button
- Link to sign-in page

### 3. Add Client-Side Validation

Implement real-time validation:
- Password strength indicator
- Matching confirmation check
- Email format validation
- Show requirements as user types

### 4. Add Routing

Add route in `router.ex`:
```elixir
live "/register", AuthLive.Register, :index
```

### 5. Update Sign-In Page

Add "Need an account?" link pointing to registration page.

## Form Implementation Details

### Registration Form Fields

1. **Email**
   - type="email"
   - Required
   - Unique validation
   - Clear error for duplicates

2. **Password**
   - type="password"
   - Minimum 8 characters
   - Show/hide toggle
   - Requirements list

3. **Password Confirmation**
   - type="password"
   - Must match password
   - Real-time matching indicator

4. **Display Name** (optional)
   - type="text"
   - Placeholder with example
   - Falls back to email if not provided

## Testing Requirements

1. **Unit Tests**
   - Form rendering with all fields
   - Validation logic
   - Success/error handling

2. **Integration Tests**
   - Successful registration flow
   - Duplicate email handling
   - Password mismatch handling
   - Auto-sign in after registration

3. **Feature Tests**
   - New feature test for registration flow
   - Test optional display name
   - Test validation feedback

## Success Criteria

- [ ] Registration form renders with all fields
- [ ] Client-side validation provides helpful feedback
- [ ] Successful registration creates user and signs them in
- [ ] Duplicate emails show clear error message
- [ ] Password requirements are clearly communicated
- [ ] All registration tests pass

## Notes

- Consider adding terms of service checkbox in future
- May want to add captcha for bot prevention
- Email verification could be added later
- Keep registration simple for MVP