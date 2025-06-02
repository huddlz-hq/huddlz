# Issue #27: Allow for Password Authentication

## Overview
Add password authentication alongside existing magic link authentication using Ash Authentication's built-in support for multiple strategies.

## Requirements Summary

1. **Authentication Methods**: Both magic links and passwords available on same account
2. **Registration**: Choice between methods with DaisyUI radio buttons
3. **Password Requirements**: Use Ash Authentication defaults
4. **Password Reset**: Use Ash Authentication's built-in flow
5. **Existing Users**: No forced migration, can continue with magic links only
6. **Sign-In UI**: Two forms with DaisyUI divider between them
7. **Security**: Trust Ash Authentication's default behavior
8. **Profile Page**: Simple password change form (add/update password)
9. **Error Handling**: Use Ash Authentication's default messages

## Task Breakdown

### Task 1: Add Password Strategy to User Resource
- Add password strategy to authentication block
- Add hashed_password attribute
- Configure password actions (register, sign_in, reset)
- Verify existing magic link users remain unaffected

### Task 2: Generate and Run Database Migration
- Generate Ash migration for hashed_password field
- Run migration
- Verify schema changes

### Task 3: Update Sign-In Page UI
- Create two-form layout with DaisyUI divider
- Password form with email/password fields
- Magic link form (existing)
- Verify Ash Phoenix components work as expected

### Task 4: Create Registration Page
- New route /register
- DaisyUI radio buttons for method selection
- Dynamic form based on selection
- Handle both registration flows

### Task 5: Implement Password Management in Profile
- Add password change form to profile page
- Handle both "set password" and "change password" cases
- Password and password_confirmation fields
- Success/error feedback

### Task 6: Update Routes and Navigation
- Add /register route
- Add password reset routes
- Update navigation links
- Ensure all auth flows are accessible

### Task 7: Testing and Edge Cases
- Test new user registration (both methods)
- Test existing user with magic link only
- Test password reset flow
- Test sign-in with both methods
- Test password change scenarios
- Verify error handling

## Success Criteria

1. New users can register with either method
2. Existing users can continue using magic links without disruption
3. Users can sign in with either method if both are set up
4. Password reset flow works correctly
5. Users can add/change passwords from profile
6. All forms use DaisyUI components consistently
7. Ash Authentication defaults are leveraged throughout

## Technical Notes

- Leverage Ash Authentication's built-in strategies
- Use existing AshAuthentication.Phoenix components where possible
- Maintain backward compatibility for existing users
- Follow existing code patterns for forms and LiveViews