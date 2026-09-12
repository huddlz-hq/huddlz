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

  Scenario: Huddlz in private groups count too
    Given a private group "Quiet Club" exists with owner "owner553@example.com"
    And the in-person huddl "Members only" in "Quiet Club" ended 3 days ago with 2 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the Huddlz held KPI shows "1"
    And the RSVPs KPI shows "2"

  Scenario: Figures move with the period
    Given the in-person huddl "Old" in "Portland Elixir" ended 60 days ago with 5 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the Huddlz held KPI shows "1"
    When I click "30 days"
    Then the Huddlz held KPI shows "0" and "Nothing in this period"

  Scenario: Groups are ranked by the activity they carried
    Given the in-person huddl "Kickoff" in "Portland Elixir" ended 10 days ago with 4 RSVPs
    And the turnout for "Kickoff" was recorded as 3 in the room
    And the in-person huddl "Coffee" in "Founder Coffee" ended 5 days ago with 2 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the most active groups list "Portland Elixir" before "Founder Coffee"
    And the active group row for "Portland Elixir" shows "4 RSVPs" and "75%"
    And the active group row for "Founder Coffee" shows no show rate

  Scenario: A quiet platform says so
    Given I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the People KPI shows "3" and "+3 in 90 days"
    And the Show rate KPI reads as not yet available
    And I should see "No group held a huddl in this period."
    And I should see "Nothing scheduled in the next 30 days."

  Scenario: Coming up counts the next 30 days
    Given the in-person huddl "Next week" in "Portland Elixir" is upcoming with 3 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the Coming up panel shows "1" huddl and "3" RSVPs
    And the Coming up panel lists "Next week"

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
