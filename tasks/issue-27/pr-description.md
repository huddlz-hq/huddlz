## Summary

Implements password authentication as an additional authentication method alongside the existing magic link system. Users can now choose between password-based or magic link authentication when registering or signing in.

Closes #27

## Changes

### Core Authentication
- Added password strategy to User resource using Ash Authentication defaults
- Implemented all password-related actions: register, sign in, change password, reset password
- Created `set_password` action for users without existing passwords
- Added policies to control password management access

### UI Updates
- Sign-in page now displays both password and magic link forms
- Registration page offers both authentication methods
- Profile page includes collapsible password management section
- Password reset flow integrated with dual-method approach

### Testing & Infrastructure
- Fixed PhoenixTest multi-form issues using ID-based selectors
- Created comprehensive unit tests for password functionality
- Added Cucumber feature tests for all user flows
- Updated test generator with `user_with_password` helper

## Testing

To test the implementation:

1. **Registration Flow**:
   - Visit `/register` and test both password and magic link registration
   - Verify both methods create functional accounts

2. **Sign-In Flow**:
   - Visit `/sign-in` and test both authentication methods
   - Verify users can sign in with either method if both are set up

3. **Password Management**:
   - Sign in and visit `/profile`
   - Test setting password for magic-link-only users
   - Test changing password for users with existing passwords

4. **Password Reset**:
   - Visit `/reset` and test the password reset flow
   - Verify reset emails are sent and tokens work correctly

5. **Run Test Suite**:
   ```bash
   mix test  # All 301 tests should pass
   ```

## Learnings

1. **Ash Generators Provide Most Functionality**: The generators created ~90% of needed code including routes, actions, and basic UI. Always check generator output before custom implementation.

2. **Multi-Form Testing Pattern**: When pages have multiple forms with similar fields, use ID-based selectors (`#field-id`) with PhoenixTest to avoid ambiguity. This pattern proved essential for reliable testing.

## Screenshots

The implementation maintains the existing UI style while adding password functionality:
- Sign-in page shows both forms with "or" separator
- Profile page has collapsible password section
- All forms follow consistent styling patterns