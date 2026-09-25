@async @database @conn @admin_overview
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
    Then the platform "Active people" figure shows "1"
    And the platform "Groups" figure shows "2" and "2 held a huddl"
    And the platform "Huddlz held" figure shows "2"
    And the platform "RSVPs" figure shows "6"
    And the platform "Show rate" figure shows "75%" and "1 of 2 past huddlz counted"

  Scenario: Private group content is excluded without membership
    Given a private group "Quiet Club" exists with owner "owner553@example.com"
    And the in-person huddl "Members only" in "Quiet Club" ended 3 days ago with 2 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the platform "Huddlz held" figure shows "0"
    And the platform "RSVPs" figure shows "0"

  Scenario: Figures move with the period
    Given the in-person huddl "Old" in "Portland Elixir" ended 60 days ago with 5 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the platform "Huddlz held" figure shows "1"
    When I click "30 days"
    Then the platform "Huddlz held" figure shows "0" and "Nothing in this period"

  Scenario: Groups are ranked by the activity they carried
    Given the in-person huddl "Kickoff" in "Portland Elixir" ended 10 days ago with 4 RSVPs
    And the turnout for "Kickoff" was recorded as 3 in the room
    And the in-person huddl "Coffee" in "Founder Coffee" ended 5 days ago with 2 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the most active groups list "Portland Elixir" before "Founder Coffee"
    And the active group row for "Portland Elixir" shows "4 RSVPs" and "75%"
    And the active group row for "Founder Coffee" shows no show rate

  Scenario: Active groups count RSVPs for huddlz held in the selected period
    Given the in-person huddl "Recent" in "Portland Elixir" ended 10 days ago with 4 RSVPs
    And the RSVPs for "Recent" were made 100 days ago
    And 2 people are waitlisted for "Recent"
    And the in-person huddl "Earlier" in "Portland Elixir" ended 60 days ago with 2 RSVPs
    And the in-person huddl "Last season" in "Portland Elixir" ended 150 days ago with 3 RSVPs
    And the in-person huddl "Next week" in "Portland Elixir" is upcoming with 8 RSVPs
    And the in-person huddl "Future coffee" in "Founder Coffee" is upcoming with 20 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin?period=30d"
    Then the active group row for "Portland Elixir" shows "4 RSVPs" and "1 huddl"
    And the most active groups do not list "Founder Coffee"
    When I click "90 days"
    Then the active group row for "Portland Elixir" shows "6 RSVPs" and "2 huddlz"
    When I click "12 months"
    Then the active group row for "Portland Elixir" shows "9 RSVPs" and "3 huddlz"

  Scenario: A quiet platform says so
    Given I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the platform "People" figure shows "3" and "+3 recorded in 90 days"
    And the platform "Show rate" figure shows "—" and "No turnout recorded yet"
    And I should see "No group held a huddl in this period."
    And I should see "Nothing scheduled in the next 30 days."

  Scenario: Coming up counts the next 30 days
    Given the in-person huddl "Next week" in "Portland Elixir" is upcoming with 3 RSVPs
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the Coming up panel shows "1" huddl and "3" RSVPs
    And the Coming up panel lists "Next week"

  @dashboard_overview
  Scenario: Platform figures are available through the dashboard only
    Given the in-person huddl "Kickoff" in "Portland Elixir" ended 10 days ago with 4 RSVPs
    When "admin553@example.com" reads the platform overview for "90d" through GraphQL
    Then the API refuses the platform overview
    When "owner553@example.com" reads the platform overview for "90d" through GraphQL
    Then the API refuses the platform overview

  Scenario: User management lives under Users
    Given I am signed in as "admin553@example.com"
    When I visit "/admin/users"
    Then I should see "Owner Olive"
    And I can change the role of "member553@example.com"

  Scenario: Platform day buckets begin at midnight UTC
    When "admin553@example.com" views the platform overview for "30d"
    Then the platform chart buckets begin at midnight UTC
    When "admin553@example.com" views the platform overview for "90d"
    Then the platform chart buckets begin at midnight UTC

  Scenario: The annual total and chart cover the same twelve calendar months
    Given a huddl in "Portland Elixir" ended just before the twelve calendar months
    And a huddl in "Portland Elixir" ended in the first of the twelve calendar months
    When "admin553@example.com" views the platform overview for "12m"
    Then the annual platform total and chart both show 1 huddl held

  Scenario: Estimated account dates do not pretend to be measured sign-ups
    Given the sign-up date for "owner553@example.com" was estimated from confirmation
    And the sign-up date for "member553@example.com" was estimated from migration
    And I am signed in as "admin553@example.com"
    When I visit "/admin"
    Then the platform "People" figure shows "3" and "+1 recorded in 90 days"
    And I should see "2 accounts have estimated sign-up dates, excluded from growth."
