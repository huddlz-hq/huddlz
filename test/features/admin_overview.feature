@database @conn @admin_overview
Feature: Admin platform overview
  As an administrator
  I want one page with platform-wide figures
  So that I can tell whether huddlz is growing and being used

  Background:
    Given the following users exist:
      | email                 | role  | display_name |
      | admin553@example.com  | admin | Admin Alex   |
      | owner553@example.com  | user  | Owner Olive  |
      | member553@example.com | user  | Member Maya  |
    And a public group "Portland Elixir" exists with owner "owner553@example.com"
    And a public group "Founder Coffee" exists with owner "owner553@example.com"

  Scenario: Only administrators can open the overview
    Given I am signed in as "owner553@example.com"
    When I visit "/admin"
    Then I should see "You don't have access to the admin area."

  Scenario: The overview counts the whole platform
    Given "member553@example.com" is a member of "Portland Elixir"
    And the in-person huddl "Kickoff" in "Portland Elixir" ended 10 days ago with 4 RSVPs
    And the turnout for "Kickoff" was recorded as 3 in the room
    And the in-person huddl "Coffee" in "Founder Coffee" ended 5 days ago with 2 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the Active people KPI shows "8"
    And the Groups KPI shows "2" and "2 held a huddl"
    And the Huddlz held KPI shows "2"
    And the RSVPs KPI shows "6"
    And the Show rate KPI shows "75%" and "1 of 2 past huddlz counted"

  Scenario: Figures move with the period
    Given the in-person huddl "Old" in "Portland Elixir" ended 60 days ago with 5 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the Huddlz held KPI shows "1"
    When I click "30 days"
    Then the Huddlz held KPI shows "0" and "Nothing in this period"

  Scenario: The overview figures are an action administrators can call through the API
    Given the in-person huddl "Kickoff" in "Portland Elixir" ended 10 days ago with 4 RSVPs
    When "admin553@example.com" reads the platform overview for "90d" through GraphQL
    Then the API platform overview shows 1 huddl held and 4 RSVPs
    When "owner553@example.com" reads the platform overview for "90d" through GraphQL
    Then the API refuses the platform overview

  Scenario: User management lives under Users
    Given I am signed in as "admin553@example.com"
    When I visit "/admin/users"
    Then I should see "Owner Olive"
    And I can change the role of "member553@example.com"
