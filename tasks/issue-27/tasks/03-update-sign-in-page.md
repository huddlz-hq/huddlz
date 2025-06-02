# Task 3: Update Sign-In Page UI

## Objective
Modify the sign-in page to show both authentication options with DaisyUI styling.

## Checklist

- [ ] Update sign-in LiveView/template to show two forms
- [ ] Add DaisyUI divider between forms
- [ ] Create password sign-in form with email/password fields
- [ ] Keep existing magic link form
- [ ] Style both forms consistently with DaisyUI
- [ ] Ensure proper form actions and CSRF tokens
- [ ] Add "Forgot password?" link to password form
- [ ] Test both sign-in methods work correctly

## Implementation Details

1. Update sign-in page (likely `lib/huddlz_web/controllers/auth_controller.ex` or LiveView):
   - Two-column layout or stacked forms
   - DaisyUI divider component between them
   - Clear labels for each method

2. Password form should include:
   - Email input (text field)
   - Password input (password field)
   - Submit button ("Sign in with Password")
   - "Forgot password?" link

3. Magic link form (existing):
   - Email input
   - Submit button ("Send Magic Link")

4. Example DaisyUI structure:
   ```html
   <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
     <div><!-- Password form --></div>
     <div class="divider md:divider-horizontal">OR</div>
     <div><!-- Magic link form --></div>
   </div>
   ```

## Success Criteria

- Both forms display correctly
- Forms are responsive on mobile/desktop
- DaisyUI styling is consistent
- Both authentication methods work
- User experience is clear and intuitive