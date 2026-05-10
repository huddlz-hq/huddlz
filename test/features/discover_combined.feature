@async @database @conn
Feature: Combined search on /discover
  As a visitor browsing huddlz
  I want a single discover surface that can switch between huddlz and groups
  So that I can find either type of community without leaving the page

  Background:
    Given the following users exist:
      | email             | role     | display_name |
      | host@example.com  | verified | Group Host   |

  Scenario: Default scope shows both scope chips
    When I visit "/discover"
    Then I should see "Huddlz"
    And I should see "Groups"

  Scenario: scope=groups shows the groups section
    Given a group named "Tampa Tech Talks" is owned by "host@example.com"
    When I visit "/discover?scope=groups"
    Then I should see "Browse groups"
    And I should see "Tampa Tech Talks"

  Scenario: scope=groups hides huddlz
    Given a group named "Tampa Tech Talks" is owned by "host@example.com"
    And the group "Tampa Tech Talks" has an upcoming huddl titled "Builders Night"
    When I visit "/discover?scope=groups"
    Then I should see "Tampa Tech Talks"
    And I should not see "Builders Night"

  Scenario: scope=groups empty state
    When I visit "/discover?scope=groups&q=zzznomatchforanything"
    Then I should see "No groups match this search"
