# Task 5: Implement profile update functionality

## Status: ⏳ Pending

## Description
Complete the profile form functionality to allow users to update their display name.

## Requirements
1. Wire up form to handle display name updates
2. Add validation for 1-30 character length
3. Show success flash message after update
4. Handle and display any errors appropriately

## Technical Details
- May use existing `update_display_name` action or implement as needed
- Validation should prevent empty names and enforce length limits
- Flash message: "Display name updated successfully"
- Consider using `phx-submit` and `phx-change` events

## Acceptance Criteria
- [ ] Form successfully updates display name in database
- [ ] Display names must be 1-30 characters
- [ ] Success shows flash message
- [ ] Validation errors display appropriately
- [ ] Updated name appears immediately in navbar
- [ ] Form resets or updates after successful save

## Error Handling
- Too short: "Display name must be at least 1 character"
- Too long: "Display name must be no more than 30 characters"
- Server errors: Generic message with retry option

## Testing Notes
- Test validation boundaries (0, 1, 30, 31 characters)
- Test special characters are accepted
- Test that navbar updates without page refresh