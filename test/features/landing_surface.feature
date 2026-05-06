@async @database @conn
Feature: Landing surface
  As a first-time visitor
  I want a clear pitch on the home page
  So that I understand what huddlz is before I start searching

  Background:
    Given the following users exist:
      | email             | role     | display_name |
      | regular@example.com | verified | Regular User |

  Scenario: Anonymous visitor sees the landing hero and CTAs
    When I visit "/"
    Then I should see "Find your next real-life gathering."
    And I should see "Find your people, fast"
    And I should see "Search huddlz"
    And I should see "Run the community, not the tooling."
    And I should see "Open organize"

  Scenario: Anonymous visitor sees the three value tiles
    When I visit "/"
    Then I should see "Discover quickly"
    And I should see "Meet in real life"
    And I should see "Organize without clutter"

  Scenario: Authenticated user is redirected from / to /me
    Given I am signed in as "regular@example.com"
    When I visit "/"
    Then I should see "Welcome back, Regular."
    And I should see "// Your dashboard"
