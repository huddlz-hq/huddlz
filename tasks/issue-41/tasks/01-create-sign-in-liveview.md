# Task 1: Create Sign-In LiveView

**Status**: completed
**Started**: 2025-01-06 10:00 AM
**Completed**: 2025-01-06 11:30 AM

## Objective

Replace the default AshAuthentication.Phoenix sign-in page with a custom LiveView that provides better UX and branding while maintaining all authentication functionality.

## Requirements

1. Create a custom `SignInLive` module
2. Support both magic link and password authentication
3. Clear visual separation between authentication methods
4. Proper error handling and loading states
5. Links to registration and password reset pages

## Implementation Steps

### 1. Remove Default Sign-In Route

Update `router.ex` to remove the default sign-in route:
```elixir
# Remove or comment out:
# sign_in_route register_path: "/register", ...
```

### 2. Create SignInLive Module

Create `lib/huddlz_web/live/auth_live/sign_in.ex`:
- Define LiveView module
- Implement mount/3 to initialize form state
- Add handle_event/3 for form submissions
- Handle both authentication strategies

### 3. Create Sign-In Template

Create `lib/huddlz_web/live/auth_live/sign_in.html.heex`:
- Use `<.form>` component from Phoenix.Component
- Use `<.input>` helper from CoreComponents
- Use `<.button>` helper from CoreComponents
- Style with DaisyUI classes (card, form-control, btn, etc.)
- Password form section (primary)
- Magic link form section (secondary)
- Navigation links using `<.link>`
- Error display with `<.flash>` or custom alerts
- Loading states with `phx-disable-with`

### 4. Add Routing

Add custom route in `router.ex`:
```elixir
live "/sign-in", AuthLive.SignIn, :index
```

### 5. Update Navigation

Update header component to use new sign-in path.

## Form Implementation Details

### Password Authentication Form
```heex
<.form for={@password_form} phx-submit="sign_in_with_password">
  <.input field={@password_form[:email]} type="email" label="Email" required />
  <.input field={@password_form[:password]} type="password" label="Password" required />
  <.button phx-disable-with="Signing in..." class="w-full">Sign in</.button>
</.form>
```

### Magic Link Form
```heex
<.form for={@magic_form} phx-submit="request_magic_link">
  <.input field={@magic_form[:email]} type="email" label="Email" required />
  <.button phx-disable-with="Sending..." class="w-full" variant="primary">
    Send magic link
  </.button>
</.form>
```

### UI Structure
- Use DaisyUI `card` for form containers
- Use `divider` to separate auth methods
- Use `alert` for success/error messages
- Use `link` classes for navigation
- Ensure responsive design with DaisyUI utilities

## Testing Requirements

1. **Update Existing Feature Tests**
   - `sign_in_and_sign_out.feature` - Update selectors for new UI
   - `password_authentication.feature` - Update sign-in scenarios
   - Ensure all authentication flows work with new LiveView

2. **Test Updates Needed**
   - Form input selectors (likely changing from Ash defaults)
   - Button text/selectors
   - Error message locations
   - Navigation paths

3. **Run Tests After Implementation**
   ```bash
   mix test test/features/sign_in_and_sign_out.feature
   mix test test/features/password_authentication.feature
   ```

## Success Criteria

- [ ] Custom sign-in page renders correctly with navbar visible
- [ ] Sign-in LiveView is a separate module (not shared with registration)
- [ ] Password authentication works
- [ ] Magic link authentication works
- [ ] Error messages display properly
- [ ] Loading states show during submission
- [ ] Navigation links work correctly
- [ ] All existing sign-in feature tests pass (after updates)
- [ ] No regression in authentication functionality

## Notes

- Keep form names consistent with Ash expectations
- Ensure CSRF tokens are properly handled
- Maintain session redirect behavior (return to requested page)
- Consider adding "Remember me" functionality in future iteration