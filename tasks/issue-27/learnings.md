# Learnings from Issue #27: Password Authentication

**Completed**: June 2, 2025
**Duration**: Planned: ~4 hours, Actual: ~3 hours
**Complexity**: Medium - Mostly leveraging Ash defaults

## Key Insights

### 🎯 What Worked Well

1. **Ash Authentication Generators**
   - Ash generators had already created 90% of the needed functionality
   - All password actions, routes, and basic UI were pre-generated
   - Email senders were automatically created with proper configuration

2. **ID-Based Selectors for Testing**
   - Using form IDs (`#user-magic-link-request-magic-link_email`) solved multi-form ambiguity
   - PhoenixTest syntax: `fill_in("#id", "Label", with: value)` works reliably
   - This pattern scales well for pages with multiple similar forms

3. **Incremental Approach**
   - Deferring UI customization (DaisyUI styling) to focus on functionality first
   - This allowed faster implementation and clearer separation of concerns

### 🔄 Course Corrections

1. **Phoenix Server Already Running** (🔄)
   - Initially tried to start Phoenix server when using Tidewave tools
   - **Learning**: Tidewave keeps Phoenix running - no manual start needed
   - This should be documented in CLAUDE.md

2. **Multiple Form Field Selection** (🔄)
   - Cucumber tests failed with "Found 3 inputs with matching label Email"
   - **Solution**: Switch from label to ID selectors
   - **Pattern**: Always use unique IDs for form fields when multiple forms exist

3. **Test File Location** (🔄)
   - Initially looked for tests in wrong location
   - **Learning**: Feature tests go in `test/features/step_definitions/`, not `test/features/steps/`

### ⚠️ Challenges & Solutions

1. **Challenge**: Profile page password management wasn't auto-generated
   **Solution**: Manually implemented with conditional logic
   **Learning**: Ash generators create auth flows but not profile management UI

2. **Challenge**: Different validation for setting vs changing password
   **Solution**: Created separate `set_password` action without current password requirement
   **Learning**: Consider user state when designing actions - new vs existing passwords need different flows

3. **Challenge**: PhoenixTest limitations with multiple forms
   **Solution**: Use specific form IDs and field IDs
   **Learning**: Plan for unique identifiers when building multi-form pages

### 🚀 Reusable Patterns

#### Pattern: Multi-Form Field Selection
**Context**: When a page has multiple forms with similar fields
**Implementation**:
```elixir
# Instead of:
fill_in(session, "Email", with: "user@example.com")

# Use:
fill_in(session, "#user-password-sign-in-with-password_email", "Email", with: "user@example.com")
```
**Benefits**: Eliminates ambiguity, tests are more resilient

#### Pattern: Conditional Action Selection
**Context**: When the same UI needs to trigger different actions based on state
**Implementation**:
```elixir
action = if @user.hashed_password, do: :change_password, else: :set_password
form = AshPhoenix.Form.for_action(@user, action, ...)
```
**Benefits**: Single UI component handles multiple scenarios

#### Pattern: Test Helper for Authentication Methods
**Context**: Need to create users with different auth setups in tests
**Implementation**:
```elixir
defp user_with_password(opts \\ []) do
  password = Keyword.get(opts, :password, "TestPassword123!")
  user(Keyword.put(opts, :hashed_password, Bcrypt.hash_pwd_salt(password)))
end
```
**Benefits**: Consistent test data creation, explicit about auth method

## Process Insights

### Planning Accuracy
- Estimated tasks: 7
- Actual tasks: 7 (no additional tasks needed)
- Estimation accuracy: 100%

### Time Analysis
- Planned: ~4 hours
- Actual: ~3 hours
- Factors: Ash generators did more heavy lifting than expected

### Success Factors
1. Clear requirements gathering upfront (Q&A format worked well)
2. Leveraging framework defaults instead of custom implementation
3. Incremental approach - functionality first, styling later

## Recommendations

### For Similar Features
1. **Always check what Ash generators provide first** - they often create more than expected
2. **Use unique IDs for all form fields** - prevents test ambiguity
3. **Create separate actions for different user states** - don't overload single actions
4. **Document Tidewave-specific behaviors** in CLAUDE.md

### For Process Improvement
1. Add a "generator verification" step to task planning
2. Include form ID planning in UI tasks
3. Consider test implications during UI design phase

## Follow-up Items
- [ ] Update CLAUDE.md with Tidewave Phoenix server note
- [ ] Create UI enhancement issue for DaisyUI styling
- [ ] Consider adding radio button selection for registration method
- [ ] Document the multi-form testing pattern in test guidelines