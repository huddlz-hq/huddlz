# Quickstart Guide: Date Time Selection

**Feature**: Date Time Selection for Huddl Creation
**Estimated Time**: 5 minutes

## Prerequisites

1. Local development environment running:
   ```bash
   mix phx.server
   ```

2. Test user account created and logged in

3. Member of at least one group (or create a test group)

## Testing Steps

### 1. Navigate to Huddl Creation

1. Go to http://localhost:4000
2. Log in with your test account
3. Navigate to a group you're a member of
4. Click "Create Huddl" button

### 2. Test Basic Date/Time Selection

1. **Date Selection**:
   - Click the date field
   - Verify calendar picker appears
   - Verify past dates are disabled/grayed out
   - Select tomorrow's date

2. **Time Selection**:
   - Click the time field
   - Verify dropdown shows 15-minute increments (00, 15, 30, 45)
   - Select "2:30 PM" from dropdown

3. **Duration Selection**:
   - Click the duration field
   - Verify these options appear:
     - 30 minutes
     - 1 hour
     - 1.5 hours
     - 2 hours
     - 2.5 hours
     - 3 hours
     - 4 hours
     - 6 hours
   - Select "2 hours"

4. **Verify End Time Display**:
   - Check that end time shows: "Ends at: 4:30 PM"
   - Confirm date if it spans to next day

### 3. Test Manual Time Entry

1. Click the time field
2. Clear the field and type "9:47"
3. Tab out of the field
4. Verify the time is accepted (not forced to 15-minute increment)
5. Check end time updates correctly

### 4. Test Edge Cases

#### Minimum Duration
1. Select any date and time
2. Choose "30 minutes" duration (if custom entry, try entering "15")
3. Verify form accepts it

#### Maximum Duration
1. Select today's date
2. Select "11:00 PM" as start time
3. Select "6 hours" duration
4. Verify end time shows "5:00 AM (next day)" or similar indication

#### Past Date Prevention
1. Try to select yesterday's date
2. Verify it's not selectable or shows error

### 5. Test Form Submission

1. Fill in required fields:
   - Name: "Test Huddl with New Time Selection"
   - Description: "Testing the new date/time/duration pickers"
   - Event Type: Virtual
   - Date: Tomorrow
   - Time: 3:00 PM
   - Duration: 1.5 hours

2. Click "Create Huddl"

3. Verify:
   - Huddl is created successfully
   - Redirect to huddl details page
   - Start time shows: Tomorrow at 3:00 PM
   - End time shows: Tomorrow at 4:30 PM

### 6. Test Validation Errors

#### Invalid Time Format
1. Return to create huddl form
2. In time field, type "25:00"
3. Try to submit
4. Verify error: "Invalid time format"

#### Missing Required Fields
1. Fill only date and time (no duration)
2. Try to submit
3. Verify error appears for duration field

### 7. Test with Recurring Events

1. Check "Make this a recurring event"
2. Verify date/time/duration pickers still work
3. Select:
   - Frequency: Weekly
   - Repeat Until: 1 month from today
4. Submit and verify series created correctly

## Validation Checklist

✅ **Date Picker**
- [ ] Shows calendar widget
- [ ] Prevents past date selection
- [ ] Accepts today and future dates

✅ **Time Picker**
- [ ] Shows 15-minute increment options
- [ ] Allows manual entry of any valid time
- [ ] Validates time format

✅ **Duration Picker**
- [ ] Shows 8 preset options (30m to 6h)
- [ ] Calculates end time correctly
- [ ] Handles day boundary crossing

✅ **Form Behavior**
- [ ] Real-time end time calculation
- [ ] Validation on submit
- [ ] Maintains other form functionality

✅ **Data Integrity**
- [ ] Created huddl has correct start time
- [ ] Created huddl has correct end time
- [ ] Times stored in UTC

## Browser Testing

Test on:
- [ ] Chrome/Chromium
- [ ] Firefox
- [ ] Safari
- [ ] Mobile browser (responsive mode)

## Performance Check

- [ ] Form interactions respond in <200ms
- [ ] No JavaScript errors in console
- [ ] Page doesn't freeze during date/time selection

## Rollback Test

If issues are found:
1. Check feature flag (if implemented)
2. Verify fallback to original datetime-local inputs works
3. Confirm existing huddlz still display correctly

## Success Criteria

The feature is considered successful when:
1. All validation checklist items pass
2. Users can create huddlz with the new interface
3. End times are calculated correctly
4. No regression in existing functionality
5. Form responds quickly (<200ms)

## Troubleshooting

### Common Issues

**Calendar doesn't appear**:
- Check browser console for JavaScript errors
- Verify date input type is supported by browser

**Time dropdown missing options**:
- Inspect HTML to ensure datalist is rendered
- Check for CSS issues hiding the dropdown

**End time calculation wrong**:
- Verify timezone handling
- Check duration_minutes conversion
- Review server logs for calculation errors

**Form won't submit**:
- Check all required fields are filled
- Look for validation errors in server logs
- Verify Ash changeset validations

## Reporting Issues

If you encounter bugs:
1. Note the exact steps to reproduce
2. Include browser and version
3. Copy any error messages from browser console
4. Check server logs for errors
5. Take screenshots if UI issues

## Next Steps

After successful testing:
1. Test with different user roles (owner, organizer, member)
2. Create huddlz with various duration combinations
3. Verify huddlz appear correctly in calendar views
4. Test editing existing huddlz with new interface