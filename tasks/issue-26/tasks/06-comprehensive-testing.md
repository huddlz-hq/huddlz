# Task 6: Comprehensive Testing

## Objective
Write thorough tests for all slug functionality after implementation is complete.

## Test Categories

### 1. Unit Tests (Group Resource)

**File:** `test/huddlz/communities/group_test.exs`

- Test slug attribute presence and constraints
- Test unique slug validation
- Test slug generation from name
- Test manual slug override
- Test get_by_slug action

```elixir
test "generates slug from name on create" do
  {:ok, group} = Group.create_group(%{
    name: "Phoenix Elixir Meetup",
    owner_id: user.id
  })
  assert group.slug == "phoenix-elixir-meetup"
end

test "enforces unique slugs" do
  {:ok, _group1} = Group.create_group(%{
    name: "Test Group",
    slug: "test-group",
    owner_id: user.id
  })
  
  {:error, changeset} = Group.create_group(%{
    name: "Another Group", 
    slug: "test-group",
    owner_id: user.id
  })
  assert errors_on(changeset)[:slug]
end
```

### 2. LiveView Tests

**File:** `test/huddlz_web/live/group_live_test.exs`

- Test navigation with slugs
- Test form behavior (auto-generation)
- Test manual slug input
- Test edit form warnings
- Test validation error display

```elixir
test "navigates to group by slug", %{conn: conn, group: group} do
  {:ok, _view, html} = live(conn, ~p"/groups/#{group.slug}")
  assert html =~ group.name
end

test "auto-generates slug as user types", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/groups/new")
  
  view
  |> form("#group-form", group: %{name: "Test Group Name"})
  |> render_change()
  
  assert has_element?(view, "input[name='group[slug]'][value='test-group-name']")
end
```

### 3. Feature Tests (Cucumber)

**File:** `test/features/group_slugs.feature`

```gherkin
Feature: Group URL Slugs
  As a group owner
  I want my groups to have readable URLs
  So that they are easy to share and remember

  Scenario: Creating a group with auto-generated slug
    Given I am logged in as a verified user
    When I visit the new group page
    And I fill in "Group Name" with "Phoenix Elixir Meetup"
    Then the "URL Slug" field should contain "phoenix-elixir-meetup"
    When I submit the form
    Then I should be at "/groups/phoenix-elixir-meetup"

  Scenario: Handling slug collisions
    Given a group exists with slug "book-club"
    And I am logged in as a verified user
    When I create a group named "Book Club"
    Then I should see "This slug is already taken"
    When I fill in "URL Slug" with "book-club-2"
    And I submit the form
    Then the group should be created successfully

  Scenario: Editing a group slug
    Given I own a group with slug "old-slug"
    When I edit the group
    And I change the slug to "new-slug"
    Then I should see a warning about breaking links
    When I save the changes
    Then I should be redirected to "/groups/new-slug"
```

### 4. Integration Tests

- Test full user flows
- Test slug-based routing
- Test all group-related features with slugs
- Test error scenarios

### 5. Edge Cases to Test

- Unicode characters in names
- Very long names (truncation)
- Special characters handling
- Empty/nil slug attempts
- Slug format validation
- Case sensitivity

## Test Execution Plan

1. Run all existing tests to ensure no regression
2. Add new unit tests for slug functionality
3. Update existing tests that use group IDs
4. Add LiveView tests for forms
5. Create feature tests for user flows
6. Manual testing in browser

## Acceptance Criteria
- [ ] All existing tests still pass
- [ ] New unit tests cover slug logic
- [ ] LiveView tests verify form behavior
- [ ] Feature tests cover user scenarios
- [ ] Edge cases are tested
- [ ] No regression in functionality

## Quality Gates
Before marking complete:
- `mix test` - All pass
- `mix test test/features/` - All pass
- `mix format` - No changes
- `mix credo --strict` - No issues