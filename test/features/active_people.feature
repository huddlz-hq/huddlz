@database @conn @active_people
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
