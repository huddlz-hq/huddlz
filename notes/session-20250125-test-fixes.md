# Test Fixes Session - 2025-01-25

## Summary

Fixed remaining Cucumber test failures after Wallaby migration. Tests were failing due to UI mismatches and authentication session issues.

## Tests Fixed

### 1. Complete Signup Flow Test
- Changed "Submit" button to "Request magic link"
- Updated flash message to exact text
- Fixed user creation action from `:register_with_magic_link` to `:create`
- Removed email assertion for new users (security feature)

### 2. Signup with Magic Link Tests  
- Updated button text from "Submit" to "Request magic link"
- Fixed flash message assertion
- Updated validation error handling (HTML5 validation prevents submission)
- Removed unnecessary import

### 3. Huddl Listing Tests
- Fixed search input selector to use placeholder attribute
- Updated assertions to verify ALL huddlz visible, not just one
- Fixed "No huddlz found" logic

### 4. Create Huddl Tests (Partial)
- Fixed button detection with XPath for buttons containing icons
- Authentication works (shows "You are now signed in")
- Session persistence issue between pages remains

## Key Fixes Applied

1. **Button/Link Detection**: Use XPath for partial text matching when buttons contain icons:
   ```elixir
   Query.xpath(~s|//a[contains(., "Create Huddl")]|)
   ```

2. **Form Field Selectors**: 
   - Search by placeholder: `css("input[placeholder*='Search']")`
   - Labels in spans: `css("span.fieldset-label", text: "Label")`

3. **Flash Messages**: Always use exact text with role="alert":
   ```elixir
   assert_has(session, css("[role='alert']", text: "Exact message"))
   ```

4. **Authentication**: Magic link auth works but session may not persist across page navigations in tests

## Test Results

- **Before**: 15/29 passing (14 failures)
- **After**: 16/29 passing (13 failures)
- **Fixed**: Complete signup flow test
- **Improved**: Better assertions in multiple tests

## Remaining Issues

1. **Session Persistence**: LiveView sessions not persisting between page loads in Wallaby
2. **Create Huddl Tests**: Form tests fail because user appears logged out on form page
3. **Group Management Tests**: Similar session issues
4. **RSVP Tests**: Need to implement RSVP functionality checks

## Recommendations

1. The session persistence issue is a known challenge with LiveView + Wallaby
2. Consider using a different authentication approach for tests
3. Or accept that some integration tests may need to be written differently
4. The test infrastructure is solid - remaining failures are mostly due to the session issue