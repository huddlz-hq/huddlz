@async @database @conn @active_people
Feature: Active people
  As an administrator
  I want to know how many people used huddlz over a period
  So that I can tell whether huddlz is being used, not only joined

  Background:
    Given the following users exist:
      | email                 | role  | display_name |
      | admin564@example.com  | admin | Admin Alex   |
      | owner564@example.com  | user  | Owner Olive  |
      | member564@example.com | user  | Member Maya  |
      | quiet564@example.com  | user  | Quiet Quinn  |
    And a public group "Portland Elixir" exists with owner "owner564@example.com"

  Scenario: Browsing a huddl while signed in counts as using huddlz
    Given the in-person huddl "Kickoff" in "Portland Elixir" is upcoming with 0 RSVPs
    And I am signed in as "member564@example.com"
    When I visit the huddl "Kickoff"
    Then "member564@example.com" is counted as active today

  Scenario: Using huddlz several times in a day counts once
    Given I am signed in as "member564@example.com"
    When I visit "/discover"
    And I visit "/groups"
    Then "member564@example.com" is counted as active today once

  Scenario: A visitor does not count
    When I visit "/discover"
    Then nobody is counted as active today

  Scenario: Using the API counts
    When "member564@example.com" reads their account through GraphQL
    Then "member564@example.com" is counted as active today

  Scenario: A change applied by someone else does not make a person active
    Given "quiet564@example.com" is a member of "Portland Elixir"
    When the owner removes "quiet564@example.com" from "Portland Elixir"
    Then "quiet564@example.com" is not counted as active today

  Scenario: Viewing huddlz as someone counts the administrator
    Given I am signed in as "admin564@example.com"
    And I visit "/admin/users"
    And I choose to view as "member564@example.com"
    When I visit "/discover"
    Then "admin564@example.com" is counted as active today
    And "member564@example.com" is not counted as active today

  # The administrator's own visit to the overview counts them too.
  @coverage_start
  Scenario: Collection covers days before anyone used huddlz
    Given usage measurement began 200 days ago
    When "admin564@example.com" views the platform overview for "30d"
    Then the overview reports usage measured from 200 days ago
    And the overview reports 0 active people in the previous period

  Scenario: The overview counts distinct people over the period
    Given usage measurement began 200 days ago
    And "owner564@example.com" used huddlz 200 days ago
    And "member564@example.com" used huddlz 1 day ago
    And "member564@example.com" used huddlz 3 days ago
    And "quiet564@example.com" used huddlz 100 days ago
    And I am signed in as "admin564@example.com"
    When I visit "/admin"
    Then the platform "Active people" figure shows "2" and "+100% vs previous 90 days"

  Scenario: Periods before measurement began are not compared
    Given usage measurement began 3 days ago
    And "member564@example.com" used huddlz 3 days ago
    And I am signed in as "admin564@example.com"
    When I visit "/admin"
    Then the platform "Active people" figure shows "2" and "Measured since"

  Scenario: The overview carries the figure with its coverage
    Given usage measurement began 3 days ago
    And "member564@example.com" used huddlz 3 days ago
    When "admin564@example.com" views the platform overview for "30d"
    Then the overview active people figure counts 2 people measured from 3 days ago with no comparison

  @partial_launch_day
  Scenario: The partial first day does not provide a full previous period
    Given usage measurement began 59 days ago
    And "member564@example.com" used huddlz 59 days ago
    When "admin564@example.com" views the platform overview for "30d"
    Then the overview reports usage measured from 59 days ago
    And the overview reports no active people comparison

  Scenario: A previous period beginning after the launch day can be compared
    Given usage measurement began 60 days ago
    And "member564@example.com" used huddlz 59 days ago
    When "admin564@example.com" views the platform overview for "30d"
    Then the overview reports 1 active people in the previous period

  Scenario: Deleting the earliest active account preserves collection coverage
    Given usage measurement began 200 days ago
    And "quiet564@example.com" used huddlz 200 days ago
    And "member564@example.com" used huddlz 100 days ago
    And the account "quiet564@example.com" has been deleted
    When "admin564@example.com" views the platform overview for "90d"
    Then the overview reports usage measured from 200 days ago
    And the overview reports 1 active people in the previous period
