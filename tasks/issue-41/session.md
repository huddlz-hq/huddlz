# Issue 41: Custom Authentication Pages - Session Notes

## Session Start: Planning Phase

### Initial Analysis

Examined the codebase to understand issue #41. Found:
- Git branch `issue-41-custom-auth-pages` exists
- Router comments explicitly mention removing default auth views
- Current implementation uses AshAuthentication.Phoenix's built-in views
- AuthOverrides module only does minor styling

### Requirements Discovery

The issue is about replacing the default authentication views with custom LiveView pages. This will provide:
- Better branding and user experience
- Separation of authentication strategies by page
- More control over the authentication flow
- Consistent design with the rest of the application

### Technical Analysis

Current authentication setup:
1. Uses `sign_in_route` and `reset_route` macros from AshAuthentication.Phoenix
2. Both magic link and password strategies configured in User resource
3. All strategies shown on all pages (not ideal UX)
4. Limited customization through overrides

### Plan Created

Created comprehensive plan with 5 tasks:
1. Create Sign-In LiveView
2. Create Registration LiveView  
3. Create Password Reset LiveView
4. Create Set Password LiveView
5. Update Navigation and Polish

Each task includes implementation, routing, and testing.

## Plan Revision

After discussion with user, revised plan to address key requirements:

### Key Requirements Clarified

1. **Each auth page must be its own LiveView** - This ensures each page is wrapped in `Layout.app` so the navbar is visible on all authentication pages
2. **All existing tests must continue passing** - We're not creating new tests, but updating existing feature tests as needed
3. **Update tests after each task** - Ensure tests pass after completing each task, not just at the end

### Understanding Layout Structure

- The app uses `Layout.app` which includes the navbar
- Current auth pages don't show navbar because they use different layouts
- Each custom LiveView will automatically use the app layout
- This provides consistent navigation experience

### Test Strategy

Existing auth-related feature tests:
- `sign_in_and_sign_out.feature` - Magic link sign in flows
- `password_authentication.feature` - Password registration, sign in, reset
- `signup_with_magic_link.feature` - Magic link signup
- `complete_signup_flow.feature` - Full registration flow

These tests use specific selectors and expect certain UI elements. As we implement each custom page, we'll need to:
1. Run the relevant tests
2. Update selectors/steps as needed for new UI
3. Ensure functionality remains the same
4. Verify all tests pass before moving to next task

## UI Framework Requirements

User clarified additional requirements:

### DaisyUI Components
- All UI elements must use DaisyUI classes
- DaisyUI is already included in Phoenix 1.8
- Use existing CoreComponents helpers

### CoreComponents Usage
- Leverage `<.input>`, `<.button>`, `<.flash>` helpers
- Use `<.form>` from Phoenix.Component
- Maintain consistency with existing UI patterns

### Updated Plan
- Updated all task files to reflect DaisyUI usage
- Added code examples showing proper component usage
- Emphasized using existing helpers over custom HTML

## Next Steps

Ready to begin implementation with Task 1: Create Sign-In LiveView using DaisyUI components and CoreComponents helpers.