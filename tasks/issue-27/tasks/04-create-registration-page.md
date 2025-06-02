# Task 4: Create Registration Page

## Objective
Build a new registration page where users can choose between password and magic link signup.

## Checklist

- [ ] Create new registration route (/register)
- [ ] Build registration LiveView or controller
- [ ] Add DaisyUI radio buttons for method selection
- [ ] Implement dynamic form that changes based on selection
- [ ] Password form: email, password, password_confirmation
- [ ] Magic link form: just email
- [ ] Handle form submission for both methods
- [ ] Add proper error handling and validation display
- [ ] Update navigation to include "Sign up" link

## Implementation Details

1. Add route in `lib/huddlz_web/router.ex`:
   ```elixir
   live "/register", RegisterLive
   ```

2. Create registration UI with:
   - DaisyUI radio button group at top
   - Dynamic form below that changes based on selection
   - Smooth transition between forms

3. Radio button example:
   ```html
   <div class="form-control">
     <label class="label cursor-pointer">
       <span class="label-text">Sign up with Password</span>
       <input type="radio" name="method" class="radio" value="password" />
     </label>
     <label class="label cursor-pointer">
       <span class="label-text">Sign up with Magic Link</span>
       <input type="radio" name="method" class="radio" value="magic_link" />
     </label>
   </div>
   ```

4. Form handling:
   - Password: Call register_with_password action
   - Magic link: Call existing request_magic_link action

## Success Criteria

- Registration page accessible at /register
- Radio buttons switch between forms smoothly
- Both registration methods work correctly
- Validation errors display properly
- Success redirects appropriately
- Navigation updated to include registration option