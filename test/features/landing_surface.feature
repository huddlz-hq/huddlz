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
    Then I should see "Find your people."
    And I should see "Run the meetup."
    And I should see "In-person and online · everywhere"
    And I should see "Browse huddlz"
    And I should see "Start a group"

  Scenario: Anonymous visitor sees the three value tiles
    When I visit "/"
    Then I should see "Discovery that learns you"
    And I should see "Organize without the spreadsheet"
    And I should see "Bring your agent"

  Scenario: Anonymous visitor sees sign-in and sign-up links in the topbar
    When I visit "/"
    Then I should see "Sign in"
    And I should see "Sign up"

  Scenario: Authenticated user is redirected from / to /me
    Given I am signed in as "regular@example.com"
    When I visit "/"
    Then I should see "My huddlz."
    And I should see "// Signed in"
