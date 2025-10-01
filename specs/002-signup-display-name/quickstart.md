# Quickstart: Signup Display Name Testing

## Overview

This quickstart guide provides step-by-step manual testing instructions to verify the signup display name feature is working correctly.

## Prerequisites

- Development environment running (`mix phx.server`)
- Database migrated with display_name constraint updates
- Clean test database or ability to use unique test emails

## Test Scenarios

### Scenario 1: Display Name Field Presence

**Objective**: Verify display name field appears on signup form with appropriate guidance

**Steps**:
1. Navigate to signup page: `http://localhost:4000/register`
2. Locate the display name input field
3. Verify field label shows "Display Name"
4. Verify placeholder text shows "First and Last Name"
5. Verify field is marked as required (visual indicator)

**Expected Results**:
- ✅ Display name field is visible between email and password fields
- ✅ Placeholder text "First and Last Name" is shown when field is empty
- ✅ Field has required indicator (asterisk or visual cue)
- ✅ Field accepts keyboard input

**Pass Criteria**: All expected results met

---

### Scenario 2: Valid Display Name Signup

**Objective**: Verify user can sign up with a valid display name

**Steps**:
1. Navigate to signup page: `http://localhost:4000/register`
2. Enter email: `test-valid@example.com`
3. Enter display name: `John Doe`
4. Enter password: `testpassword123`
5. Enter password confirmation: `testpassword123`
6. Click "Sign up" button
7. Check for success message or redirect

**Expected Results**:
- ✅ Form submits without errors
- ✅ User account created successfully
- ✅ Confirmation email sent message appears
- ✅ User redirected appropriately

**Verification**:
```elixir
# In iex -S mix
user = Huddlz.Accounts.User |> Ash.Query.filter(email == "test-valid@example.com") |> Ash.read_one!()
user.display_name
# Should return: "John Doe"
```

**Pass Criteria**: All expected results met + database verification confirms display_name saved

---

### Scenario 3: Empty Display Name Rejected

**Objective**: Verify validation prevents empty display name

**Steps**:
1. Navigate to signup page: `http://localhost:4000/register`
2. Enter email: `test-empty@example.com`
3. Leave display name field empty
4. Enter password: `testpassword123`
5. Enter password confirmation: `testpassword123`
6. Click "Sign up" button

**Expected Results**:
- ✅ Form submission blocked or error shown
- ✅ Error message near display name field: "must be present" or similar
- ✅ User remains on signup page
- ✅ No account created in database

**Pass Criteria**: All expected results met + no user in database with test email

---

### Scenario 4: Display Name Over 70 Characters Rejected

**Objective**: Verify maximum length validation works

**Steps**:
1. Navigate to signup page: `http://localhost:4000/register`
2. Enter email: `test-toolong@example.com`
3. Enter display name: `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA` (71 A's)
4. Enter password: `testpassword123`
5. Enter password confirmation: `testpassword123`
6. Click "Sign up" button

**Expected Results**:
- ✅ Form submission blocked or error shown
- ✅ Error message: "length must be less than or equal to 70" or similar
- ✅ User remains on signup page
- ✅ No account created in database

**Pass Criteria**: All expected results met

---

### Scenario 5: Single-Name Display Name Accepted

**Objective**: Verify single names (without spaces) are valid

**Steps**:
1. Navigate to signup page: `http://localhost:4000/register`
2. Enter email: `test-single@example.com`
3. Enter display name: `Madonna`
4. Enter password: `testpassword123`
5. Enter password confirmation: `testpassword123`
6. Click "Sign up" button

**Expected Results**:
- ✅ Form submits without errors
- ✅ User account created successfully
- ✅ Single-name display name accepted

**Verification**:
```elixir
user = Huddlz.Accounts.User |> Ash.Query.filter(email == "test-single@example.com") |> Ash.read_one!()
user.display_name
# Should return: "Madonna"
```

**Pass Criteria**: All expected results met + database verification

---

### Scenario 6: Special Characters and Emojis Accepted

**Objective**: Verify all printable characters including emojis work

**Test Cases**:

#### 6a: Accented Characters
**Steps**:
1. Navigate to signup page
2. Enter email: `test-accents@example.com`
3. Enter display name: `José García`
4. Complete signup with valid password

**Expected**: ✅ Account created with `display_name = "José García"`

#### 6b: Emoji
**Steps**:
1. Navigate to signup page
2. Enter email: `test-emoji@example.com`
3. Enter display name: `Sam 🎉`
4. Complete signup with valid password

**Expected**: ✅ Account created with `display_name = "Sam 🎉"`

#### 6c: Special Punctuation
**Steps**:
1. Navigate to signup page
2. Enter email: `test-punctuation@example.com`
3. Enter display name: `Mary-Jane O'Brien`
4. Complete signup with valid password

**Expected**: ✅ Account created with `display_name = "Mary-Jane O'Brien"`

**Pass Criteria**: All test cases pass + database verification

---

### Scenario 7: Display Name at Maximum Length (70 chars)

**Objective**: Verify exactly 70 characters is accepted

**Steps**:
1. Navigate to signup page: `http://localhost:4000/register`
2. Enter email: `test-maxlength@example.com`
3. Enter display name: `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA` (exactly 70 A's)
4. Enter password: `testpassword123`
5. Enter password confirmation: `testpassword123`
6. Click "Sign up" button

**Expected Results**:
- ✅ Form submits without errors
- ✅ User account created successfully
- ✅ 70-character display name stored correctly

**Verification**:
```elixir
user = Huddlz.Accounts.User |> Ash.Query.filter(email == "test-maxlength@example.com") |> Ash.read_one!()
String.length(user.display_name)
# Should return: 70
```

**Pass Criteria**: All expected results met + length verification

---

### Scenario 8: Display Name Shown Throughout Platform

**Objective**: Verify display name appears in all user contexts

**Setup**:
1. Sign up as user with display name "Test Visibility User"
2. Complete email confirmation if required
3. Sign in as the test user

**Test Points**:

#### 8a: User Profile
**Steps**: Navigate to user profile/settings page
**Expected**: ✅ Display name "Test Visibility User" shown prominently

#### 8b: Huddl Attendee List (if applicable)
**Steps**:
1. Create or join a huddl as test user
2. View the huddl's attendee list
**Expected**: ✅ Display name shown in attendee list (not email)

#### 8c: Comments/Posts (if applicable)
**Steps**:
1. Create a comment or post as test user
2. View the comment/post
**Expected**: ✅ Display name shown as author

#### 8d: Navigation/Header
**Steps**: Check user menu or profile indicator
**Expected**: ✅ Display name shown in navigation

**Pass Criteria**: Display name consistently shown in all contexts, never shows email as fallback

---

### Scenario 9: Update Display Name

**Objective**: Verify users can change their display name after signup

**Steps**:
1. Sign in as existing test user
2. Navigate to profile settings or edit profile page
3. Locate display name field
4. Change display name from current value to `Updated Display Name`
5. Save changes
6. Verify success message
7. Refresh page or navigate away and back
8. Verify new display name persists

**Expected Results**:
- ✅ Display name field editable in settings
- ✅ Same validation rules apply (1-70 chars, all characters)
- ✅ Update succeeds with valid input
- ✅ Updated display name shown immediately
- ✅ Updated display name persists across sessions

**Pass Criteria**: All expected results met

---

### Scenario 10: Update Display Name Validation

**Objective**: Verify update action has same validation as signup

**Steps**:
1. Sign in as existing test user
2. Navigate to profile settings
3. Try to update display name to empty string
4. Verify error message appears
5. Try to update display name to 71 characters
6. Verify error message appears
7. Update to valid name (e.g., `Valid Update`)
8. Verify success

**Expected Results**:
- ✅ Empty display name rejected with error
- ✅ Over-length display name rejected with error
- ✅ Valid display name accepted
- ✅ Error messages match signup validation messages

**Pass Criteria**: All expected results met

---

## Regression Tests

### Check Existing Functionality

**Objective**: Ensure new display name requirement doesn't break existing flows

**Tests**:
1. ✅ Sign in with existing user still works
2. ✅ Password reset flow still works
3. ✅ Email confirmation flow still works
4. ✅ Other profile updates (if any) still work

**Pass Criteria**: All existing authentication flows work without issues

---

## Database Verification Queries

Use these queries in `iex -S mix` to verify data integrity:

### Check all users have display names
```elixir
# Should return 0 if migration backfill worked correctly
Huddlz.Accounts.User
|> Ash.Query.filter(is_nil(display_name))
|> Ash.read!()
|> length()
```

### Check display name lengths
```elixir
# All should be between 1 and 70
Huddlz.Accounts.User
|> Ash.read!()
|> Enum.map(fn user ->
  {user.email, String.length(user.display_name || "")}
end)
```

### Check for duplicate display names (should be allowed)
```elixir
Huddlz.Accounts.User
|> Ash.read!()
|> Enum.group_by(& &1.display_name)
|> Enum.filter(fn {_name, users} -> length(users) > 1 end)
|> Enum.map(fn {name, users} ->
  {name, length(users)}
end)
```

---

## Success Criteria Summary

Feature is complete and working when:
- ✅ All 10 test scenarios pass
- ✅ Display name field present on signup form
- ✅ Display name validation works (required, 1-70 chars, all printable characters)
- ✅ Display name shown throughout platform
- ✅ Display name can be updated with same validation
- ✅ No regression in existing authentication flows
- ✅ Database integrity maintained (all users have valid display names)

## Cleanup

After testing, clean up test accounts:
```elixir
# In iex -S mix
test_emails = [
  "test-valid@example.com",
  "test-empty@example.com",
  "test-toolong@example.com",
  "test-single@example.com",
  "test-accents@example.com",
  "test-emoji@example.com",
  "test-punctuation@example.com",
  "test-maxlength@example.com"
]

Enum.each(test_emails, fn email ->
  case Huddlz.Accounts.User |> Ash.Query.filter(email == ^email) |> Ash.read_one() do
    {:ok, user} -> Ash.destroy!(user)
    _ -> :ok
  end
end)
```
