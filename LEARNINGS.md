# Project Learnings

This document captures key insights, patterns, and best practices discovered during development. It's organized by category to make information easy to find and apply to future work.

## Architecture Patterns

### Phoenix LiveView
- When building LiveView components, focus on individual purpose and reusability
- Use LiveView hooks sparingly and only when DOM manipulation is necessary
- Prefer server-side state management over client-side state when possible

### Ash Framework
- Use `before_action` hooks in resource actions to customize user attributes during signup
- Use `Ash.Changeset.change_attribute/3` to set attribute values (not `set_attribute`)
- Remember that Ash Framework functions often require context as a second parameter
- Use `authorize?: false` only when absolutely necessary (and document why)
- Keep permission policies simple and use the built-in authorization system
- Design domains around conceptual relationships between resources
- For significant data model changes, consider creating new domains
- Use many-to-many relationships with join resources for group memberships
- Generate snapshots before migrations when using Ash migrations
- **Authorization Architecture**: Use modular check modules (e.g., GroupOwner, GroupMember) for complex access control
- **Change Modules**: Custom changes (e.g., AddOwnerAsMember) elegantly handle complex business logic
- **Validation Patterns**: Cross-cutting validations (e.g., VerifiedForElevatedRoles) enforce business rules
- **CiString Usage**: Case-insensitive strings are ideal for user-facing identifiers (group names, etc.)
- **Role Modeling**: String-based roles with validation provide flexibility and type safety
- **CRITICAL**: Always follow the domain-resource-codegen sequence:
  1. Define/update the domain first
  2. Create/update the resource definition next
  3. Generate migrations last using `mix ash.codegen`
  4. Run migrations with `mix ash.migrate` (NEVER use `mix ecto.migrate`)
- **IMPORTANT**: For Ash resources, always use `mix ash.migrate` instead of `mix ecto.migrate` to ensure proper handling of resource snapshots and extensions
- **CRITICAL**: Never manually edit Ash-generated migrations. If data migration is needed:
  - In development: Delete data, regenerate clean migration
  - In production: Use separate data migration scripts
  - Manual edits break Ash's snapshot tracking system
- **Ash Commands**: Use Ash-specific mix tasks instead of Ecto equivalents:
  - `mix ash.reset` instead of `mix ecto.reset`
  - `mix ash.setup` for initial setup
  - `mix ash.codegen` to generate migrations
  - `mix ash.migrate` to run migrations
- **Change Modules**: Create custom change modules for complex attribute transformations:
  - Example: GenerateSlug module for auto-generating URL slugs
  - Handle type conversions (e.g., CiString to String) within change modules
  - Change modules run during action execution, ensuring consistency
- See `docs/ash_framework/resource_workflow.md` for the complete workflow guidance
- **Seed Data Authorization**: Use `authorize?: false` when creating seed data:
  - Seeds run without authenticated user context
  - Pattern: `|> Ash.create(authorize?: false)`
  - Only use in seed/setup scripts, never in production code

### Authentication
- Use the DSL style for auth_overrides with `override` and `set` blocks
- Don't try to update users after authentication as this conflicts with Ash's permission system
- When writing changesets in `before_action`, always include the context parameter: `fn changeset, _context ->`

## Planning & Workflow

### Planning Phase Requirements
- **ALWAYS** gather user input before creating detailed plans
- Ask clarifying questions about:
  - Specific requirements and constraints
  - Backward compatibility needs
  - Data migration considerations
  - UI/UX preferences
  - Testing requirements
- Document user responses in session notes
- Only create task breakdown after understanding full context

## Development Patterns

### Elixir Best Practices
- Use the pipe operator (`|>`) to chain operations for better readability
- Group imports by source: Elixir core modules first, then Phoenix, then project modules
- Leverage pattern matching for cleaner control flow instead of multiple conditionals
- Use module attributes for configuration values that might change

### UI Component Architecture
- **No External Libraries**: Project uses custom components, not external UI libraries
- **Component Location**: All reusable components in `core_components.ex`
- **Form Handling**: Use raw `<form>` tags with Phoenix bindings:
  - No `simple_form` helper - use standard form tags
  - Form components use `Phoenix.HTML.FormField` for field management
- **Modal Implementation**: Build modals with standard HTML/CSS:
  - Use fixed positioning and z-index for overlay
  - Click-away handling with `phx-click-away` or backdrop click events
  - No modal component libraries needed
- **Component Patterns**:
  - Function components for stateless UI (e.g., `huddl_card`)
  - Consistent prop naming with `attr` and `slot` declarations
  - Use CSS classes from DaisyUI/Tailwind for styling

### Testing Strategies
- Start with feature files using Gherkin syntax before writing implementation code
- Focus on testing behavior, not implementation details
- **PhoenixTest Migration**: When migrating from Phoenix.LiveViewTest to PhoenixTest:
  - PhoenixTest is a wrapper, not a replacement - Phoenix.ConnTest remains in support files
  - PhoenixTest cannot capture LiveView flash messages - test UI state changes instead
  - Forms require proper labels with `for` attributes for PhoenixTest's `fill_in` to work
  - Migrate entire files at once for consistency - don't mix testing approaches
  - Use `assert_has` and `refute_has` for element assertions, not raw HTML checks
  - See issue #20 learnings for detailed migration patterns
- Structure Cucumber steps to be reusable across similar scenarios
- Use generators for creating test data to avoid repetition
- Separate UI testing from business logic testing
- **Data Generation**:
  - Centralize test data generation in `test/support/generator.ex`
  - Reuse generators for both tests and seed data
  - Use `StreamData` for randomization with control
  - Use predictable test names (e.g., "Test Group 123") for stable slug generation
  - Always provide an actor for Ash operations in generators
  - Generate parent records first, then use IDs for relationships
  - **Unicode Support**: Slugify properly handles unicode by transliterating to ASCII:
    - "Café München" → "cafe-munchen"
    - "北京用户组" → "bei-jing-yong-hu-zu" (Chinese to pinyin)
    - "Москва Tech" → "moskva-tech" (Cyrillic to Latin)
    - Random unicode from StreamData can produce unpredictable slugs, so use controlled test data
- **Ash Testing Patterns**:
  - Always use `to_string()` when comparing CiString attributes in assertions
  - Use `authorize?: false` when testing data access patterns or queries
  - Must `require Ash.Query` before using Ash.Query macros in tests
  - Ash errors don't have a simple `.message` field - match on error type instead
  - When testing validation errors, check for the actual error structure fields
  - Test authorization comprehensively with all role/permission combinations
  - Use custom generators for complex test data (e.g., verified users)
  - Test edge cases like non-member access and invalid role assignments
- **Cucumber Testing**:
  - Run Cucumber tests synchronously (`async: false`) when they share data
  - Ensure users are properly persisted before authentication steps
- **LiveView Testing**:
  - All LiveView modules should wrap content in Layouts.app for consistency
  - Navigation tests may redirect to sign-in if authentication is required

### Error Handling
- Use pattern matching on error tuples (`{:error, reason}`) for explicit error handling
- Prefer descriptive error messages that identify both what went wrong and where
- When using Ash, leverage built-in error reporting and validation capabilities
- Log errors at appropriate levels (debug, info, warn, error) based on severity

## UI/UX Patterns

### Component Design
- *Add insights about UI component patterns here*

### Responsive Design
- *Add insights about responsive design approaches here*

### Accessibility
- *Add insights about accessibility patterns here*

## Issue #34: User Profiles - January 6, 2025

### Context
Implemented user profile management feature and fixed a critical bug where users were getting new random display names on every login.

### Key Learnings
1. **Upsert Fields Gotcha**: In Ash actions, `upsert_fields` determines which fields get updated during upsert operations. Including fields like `:display_name` caused them to be overwritten on every login.
2. **New Record Detection**: In Ash change modules, check `!changeset.data.id` to determine if a record is new (nil id = new record).
3. **AshPhoenix Form Handling**: Use `AshPhoenix.Form.submit` for cleaner form handling instead of manual changeset manipulation - provides better error extraction and validation.

### Reusable Patterns
- **Conditional Change Modules**: Extract complex conditional logic into Ash change modules for reusability and testability
- **DaisyUI Dropdown Navigation**: Responsive profile dropdown pattern that works seamlessly on mobile and desktop
- **Theme Toggle as Feature**: Strategic product decision to make theme customization a "logged-in user perk" to encourage signups

See `tasks/issue-34/learnings.md` for full details.

## Workflow Improvements

### Development Process
- Streamline development workflows based on feature size and complexity
- For large features, follow the full define → plan → build → verify → reflect workflow
- For smaller tasks, use the quickfix command to maintain documentation without overhead
- Automatically document session activities for continuous knowledge capture
- Structure notes consistently to make information easy to find later
- Component-based UI design can be integrated into planning rather than requiring a separate phase
- Standardize terminology to clearly distinguish between requirements docs and features
- Modularize commands to improve maintainability and flexibility
- Use product management interview techniques when planning features
- Break complex features into logical task sequences with clear dependencies
- Document architecture decisions during planning phase
- Create detailed task boundaries to prevent scope creep
- **Task Granularity**: Avoid overly small tasks (e.g., separate migration generation)
- **State Verification**: Check current system state before planning modifications
- **Duplicate Detection**: Review existing implementations to avoid redundancy
- **Access Control Documentation**: Define visibility matrices upfront for complex permissions
- **Real-time Documentation**: Update task progress immediately after each step
- **Requirements First**: ALWAYS conduct thorough requirements analysis with clarifying questions BEFORE creating sub-issues
- **Planning Phase Discipline**: The /plan command requires deep PM-style analysis - never skip this critical step

### AI Collaboration
- Start with requirements definition before implementation to ensure alignment
- Break complex tasks into manageable components when working with AI
- Maintain session notes to preserve context between AI interactions
- Use a central knowledge repository (LEARNINGS.md) to build institutional knowledge
- Allow AI to reflect on completed work to extract valuable insights

### Tooling
- Leverage custom commands to standardize development workflows
- Extract learnings from implementation immediately while they're fresh
- Use consistent parameter naming across commands for ease of use
- Create specific commands for different types of work (standard features vs. quick fixes)
- Prefer ripgrep (rg) over grep for faster and more powerful code searching
- Add ripgrep to standard toolkit recommendations for all developers
- Use angle brackets for placeholder variables in command definitions
- Use concrete examples in user-facing documentation
- Maintain clear distinction between commands and their documentation

## Performance Patterns

### Database Optimization
- *Add insights about database performance here*

### LiveView Optimization
- *Add insights about LiveView performance here*

### Asset Optimization
- *Add insights about asset optimization here*

## Common Challenges

### Known Issues
- When implementing LiveView components, be aware of client-side state reset during navigation
- Ash Framework changesets can be confusing when used with complex nested data structures
- Authentication redirects may behave unexpectedly without proper path configuration

### Workarounds
- For LiveView components that need persistent state across navigations, use localStorage or server-side session
- When Ash Framework validation is too restrictive, consider using a custom validator function
- For complex authorization rules, use function-based policies instead of DSL policies

### External Dependencies
- The Ash Framework documentation can be sparse in certain areas; refer to the GitHub repository for examples
- Phoenix LiveView's JavaScript hooks API changes between minor versions; check version compatibility
- When upgrading dependencies, always review the CHANGELOG for breaking changes

---

## How to Use This Document

1. **Before starting work on a new feature:**
   - Review relevant sections to apply established patterns
   - Check known issues to avoid repeated problems

2. **When completing a feature:**
   - Use the `/reflect` command to extract learnings
   - Add new insights to appropriate categories
   - Keep entries concise and actionable

3. **When encountering a problem:**
   - Check if a solution is documented here
   - After solving a new problem, add the solution

This document evolves over time. The goal is to build a knowledge base that improves future development efficiency and quality.

## Issue #20: Use PhoenixTest - 2025-01-26

### Context
Migrated entire test suite from Phoenix.LiveViewTest/Phoenix.ConnTest to PhoenixTest for API consistency. Successfully migrated 200+ tests including all Cucumber step definitions, LiveView unit tests, and integration tests.

### Key Learnings
1. **Framework Understanding**: PhoenixTest is a wrapper around Phoenix test tools, not a replacement. Phoenix.ConnTest remains necessary in support files.
2. **Test What Users See**: When framework limitations arise (like flash message capture), focus on testing visible UI changes rather than internal state.
3. **Accessibility Drives Testability**: PhoenixTest's requirement for proper form labels improved our HTML semantics and accessibility.

### Reusable Patterns
- **Migration Pattern**: Commit to full file migration - mixing test approaches causes confusion
- **Form Testing**: Use individual field interactions (`fill_in`, `select`, `click_button`) as PhoenixTest has no `fill_form` function
- **Assertion Strategy**: Prefer `assert_has/refute_has` over raw HTML checks for cleaner, more maintainable tests

See `tasks/issue-20/learnings.md` for full details including code examples and migration patterns.

## Issue #26: Groups Should Have Slugs - 2025-05-28

### Context
Implemented human-readable URL slugs for groups, replacing UUID-based routes. Groups now use slugs like `/groups/phoenix-elixir-meetup` instead of `/groups/123e4567...`. Full unicode support via transliteration.

### Key Learnings
1. **Ash Migration Discipline**: NEVER manually edit Ash-generated migrations - it breaks snapshot tracking. For dev: delete data and regenerate. For production: use separate data migration scripts.
2. **Unicode Excellence**: Slugify library handles international text beautifully - "北京用户组" → "bei-jing-yong-hu-zu", "Café München" → "cafe-munchen". Don't underestimate library capabilities.
3. **Type Conversions**: Ash CiString must be converted to regular String for external libraries. Always check type compatibility at integration points.
4. **Puppeteer Login Flow**: Magic link auth requires specific steps - documented in CLAUDE.md. Always use fresh tokens and navigate to mailbox detail page, not just the list.

### Reusable Patterns
- **Ash Change Modules**: Perfect for auto-generating derived attributes (like slugs from names)
- **Seed Authorization**: Use `authorize?: false` for seed scripts that lack user context
- **UI Without Libraries**: Project uses custom components - implement modals/forms with standard HTML
- **Form Simplification**: When resource handles attribute generation (force_change_attribute), simplify UI to show preview only

### Additional Insights
- **Ash vs Ecto Commands**: Always use `mix ash.*` commands (ash.reset, ash.migrate) not `mix ecto.*`
- **Test Database Cleanup**: Failed migrations can leave test DB inconsistent - manually drop columns and clean schema_migrations
- **UI Evolution**: Started with modal editing, moved to dedicated page for better UX
- **Full URL Display**: Use `url(~p"/path")` helper to show proper localhost/production URLs

See `tasks/issue-26/learnings.md` for full implementation details and code examples.

## Issue #19: Update to cucumber 0.2.0 - 2025-05-31

### Context
Upgraded cucumber from 0.1.0 to 0.4.0 (exceeding target 0.2.0) to implement shared step definitions and establish standard testing patterns. Eliminated duplication across 7 step definition files by creating SharedAuthSteps and SharedUISteps modules.

### Key Learnings
1. **Documentation Co-location**: Place documentation next to the code it describes (test/features/step_definitions/README.md) rather than in separate support directories. Improves discoverability.
2. **Pattern Categories**: Shared cucumber steps naturally organize into clear categories - Authentication (user setup, sign-in), UI Navigation (clicking, visiting), Content Assertions (seeing text, flash messages), and Form Interactions.
3. **Standard Vocabulary**: Establish consistent step patterns like "Then I should see {string} in the flash" to reduce implementation thrashing. Developers shouldn't have to figure out implementations for common tasks.

### Reusable Patterns
- **Shared Step Organization**: Group related steps in focused modules (SharedAuthSteps, SharedUISteps) with clear documentation and examples
- **Generic vs Specific**: Keep shared steps domain-agnostic - authentication and UI patterns belong in shared modules, business logic stays in feature-specific files
- **Flexible Implementation**: Support multiple existing patterns (e.g., both Ash.Seed and generate for user creation) rather than forcing uniformity

See `tasks/issue-19/learnings.md` for full details including implementation patterns and recommendations.

## Issue #27: Password Authentication - June 2, 2025

### Context
Added password authentication alongside existing magic link authentication using Ash Authentication's built-in strategies. Users can now choose between authentication methods without disrupting existing users.

### Key Learnings
1. **Ash Generators Do Heavy Lifting**: Always verify what Ash generators create first - they often provide 90% of needed functionality including routes, actions, and basic UI
2. **Multi-Form Testing Strategy**: Use ID-based selectors (`#form-field-id`) instead of label-based selectors when pages have multiple forms with similar fields. PhoenixTest syntax: `fill_in("#id", "Label", with: value)`
3. **Conditional Actions Pattern**: Design separate actions for different user states (e.g., `set_password` vs `change_password`) rather than overloading single actions with complex logic

### Reusable Patterns
- **Multi-Form Field Selection**: Always assign unique IDs to form fields when multiple forms exist on a page
- **Test Helpers for Auth Methods**: Create specific helpers like `user_with_password` to explicitly set up different authentication states
- **State-Based UI Logic**: Use conditional action selection based on resource state (e.g., presence of hashed_password field)

See `tasks/issue-27/learnings.md` for full details including implementation patterns and testing strategies.
