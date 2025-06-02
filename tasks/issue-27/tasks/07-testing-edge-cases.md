# Task 7: Testing and Edge Cases

## Objective
Comprehensive testing of all authentication scenarios and edge cases.

## Checklist

- [ ] Write/update tests for password registration
- [ ] Test sign-in with both methods
- [ ] Test existing users with magic link only
- [ ] Test password reset flow end-to-end
- [ ] Test profile password management (set and change)
- [ ] Test validation errors (weak password, mismatch, etc.)
- [ ] Test navigation and route access
- [ ] Write Cucumber features for new flows
- [ ] Ensure all existing tests still pass

## Test Scenarios

1. **New User Registration**:
   - Register with password
   - Register with magic link
   - Switch between methods during registration
   - Validation errors on password form

2. **Existing User Scenarios**:
   - Magic link user adds password
   - Password user uses magic link
   - User changes password
   - User without password accesses profile

3. **Sign-In Flows**:
   - Sign in with password (correct/incorrect)
   - Sign in with magic link
   - Switch between forms
   - Error handling

4. **Password Reset**:
   - Request reset for user with password
   - Request reset for user without password
   - Complete reset flow
   - Expired token handling

5. **Edge Cases**:
   - Simultaneous magic link and password sessions
   - Password change invalidates sessions
   - Registration with existing email
   - Concurrent authentication attempts

## Cucumber Features to Add/Update

1. `test/features/password_authentication.feature`:
   - Password registration scenarios
   - Password sign-in scenarios
   - Password management scenarios

2. Update existing features:
   - Ensure compatibility with dual auth

## Success Criteria

- All tests pass
- No regression in existing functionality
- Edge cases handled gracefully
- User experience is smooth
- Error messages are helpful
- Security is maintained