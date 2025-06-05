# Issue 41: Create Custom Authentication Pages

## Overview

Replace the default AshAuthentication.Phoenix authentication views with custom LiveView pages to provide a more branded and tailored authentication experience.

## Current State

The application currently uses the built-in authentication views from AshAuthentication.Phoenix:
- Combined sign-in/registration page at `/sign-in` and `/register`
- Password reset page at `/reset`
- Minor styling customizations via `AuthOverrides` module
- Both magic link and password authentication shown on all pages

## Objectives

1. Create custom LiveView pages for each authentication flow
2. Each page must be its own LiveView wrapped in Layout.app (for navbar visibility)
3. Maintain all existing authentication functionality
4. All existing tests must continue passing after each task
5. Update feature tests as needed to match new UI
6. Improve UI/UX with branded design
7. Ensure secure implementation following best practices

## Requirements

### UI Component Requirements

1. **Use DaisyUI Components**
   - All UI elements must use DaisyUI classes
   - Leverage existing CoreComponents helpers
   - Maintain consistent styling with rest of app
   - Use Phoenix.Component functions like `<.form>` and `<.link>`

### Functional Requirements

1. **Sign-In Page** (`/sign-in`)
   - Support both magic link and password authentication
   - Clear separation between methods
   - Link to registration page
   - Link to password reset

2. **Registration Page** (`/register`)
   - Password-based registration only
   - Email and password fields
   - Password confirmation field
   - Display name field (optional)
   - Link to sign-in page

3. **Password Reset Page** (`/reset-password`)
   - Request password reset by email
   - Clear instructions
   - Link back to sign-in

4. **Set Password Page** (`/set-password`)
   - For users who signed up with magic link to set initial password
   - Password and confirmation fields
   - Only accessible to authenticated users without password

### Non-Functional Requirements

1. **Security**
   - Maintain all current security features
   - Proper token handling
   - Session management
   - CSRF protection

2. **User Experience**
   - Clear error messages
   - Loading states during form submission
   - Success feedback
   - Responsive design

3. **Code Quality**
   - Follow existing patterns
   - Comprehensive tests
   - Documentation

## Technical Approach

1. Remove built-in authentication routes from router
2. Create custom LiveView modules for each auth page (each as separate LiveView)
3. Ensure each LiveView uses the app layout with navbar
4. Use CoreComponents helpers (`<.input>`, `<.button>`, `<.flash>`, etc.)
5. Style with DaisyUI classes (btn, input, alert, etc.)
6. Implement form handling using Ash authentication actions
7. Add custom routes with appropriate pipelines
8. Update navigation links throughout the application
9. Update existing feature tests to match new UI (not create new tests)
10. Ensure all tests pass after each task completion

## Success Criteria

- [ ] All authentication flows work as before
- [ ] Each auth page is its own LiveView with navbar visible
- [ ] Custom pages match application design
- [ ] All existing tests pass (updated as needed for new UI)
- [ ] No security regressions
- [ ] Better user experience than default pages

## Task Breakdown

### Task 1: Create Sign-In LiveView
- Remove default sign-in route
- Create custom SignInLive module
- Implement both magic link and password forms
- Add routing and navigation
- Write tests

### Task 2: Create Registration LiveView
- Create RegisterLive module
- Implement registration form with password
- Add client-side password validation
- Connect to User.register_with_password action
- Write tests

### Task 3: Create Password Reset LiveView
- Create ResetPasswordLive module
- Implement reset request form
- Handle reset token flow
- Create reset confirmation page
- Write tests

### Task 4: Create Set Password LiveView
- Create SetPasswordLive module
- Implement password setting for magic link users
- Add to profile dropdown menu
- Ensure proper access control
- Write tests

### Task 5: Update Navigation and Polish
- Update all authentication links site-wide
- Ensure consistent styling
- Add loading states and transitions
- Final testing and documentation

## Notes

- Keep `auth_routes AuthController` for handling callbacks
- Maintain backward compatibility with existing sessions
- Consider gradual rollout if needed
- Document any API changes for future reference

## References

- Router comments about removing default auth views
- Current AuthOverrides implementation
- AshAuthentication.Phoenix documentation
- Existing authentication tests