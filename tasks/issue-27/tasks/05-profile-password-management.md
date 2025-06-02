# Task 5: Implement Password Management in Profile

## Objective
Add password management form to user profile for setting or changing passwords.

## Checklist

- [ ] Update profile LiveView to include password section
- [ ] Create password change form component
- [ ] Add password and password_confirmation fields
- [ ] Detect if user has password (show "Change" vs "Set" password)
- [ ] Implement form submission and validation
- [ ] Show success/error messages with DaisyUI alerts
- [ ] Ensure form clears after successful submission
- [ ] Test both scenarios: setting first password and changing existing

## Implementation Details

1. Update `lib/huddlz_web/live/profile_live.ex`:
   - Add password management section
   - Conditional rendering based on has_password?

2. Form structure:
   ```html
   <div class="card bg-base-100 shadow-xl">
     <div class="card-body">
       <h2 class="card-title">
         <%= if @user.hashed_password, do: "Change", else: "Set" %> Password
       </h2>
       <form phx-submit="update_password">
         <div class="form-control">
           <label class="label">
             <span class="label-text">New Password</span>
           </label>
           <input type="password" name="password" class="input input-bordered" />
         </div>
         <div class="form-control">
           <label class="label">
             <span class="label-text">Confirm Password</span>
           </label>
           <input type="password" name="password_confirmation" class="input input-bordered" />
         </div>
         <button type="submit" class="btn btn-primary mt-4">
           <%= if @user.hashed_password, do: "Update", else: "Set" %> Password
         </button>
       </form>
     </div>
   </div>
   ```

3. Handle submission:
   - Call appropriate Ash action
   - Clear form on success
   - Display feedback

## Success Criteria

- Password form displays in profile
- Correct labeling for set vs change
- Validation works properly
- Success/error messages display
- Form resets after successful update
- Both use cases work correctly