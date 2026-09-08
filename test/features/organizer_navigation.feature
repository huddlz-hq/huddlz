@async @database @conn
Feature: Organizer pages highlight the group's section
  As a group owner
  I want organizer pages to highlight my group under Organizing
  So that scheduling and editing never read as browsing or as my personal lists

  Background:
    Given the following users exist:
      | email             | display_name | role    |
      | owner@example.com | Owner User   | regular |
    And a public group "Portland Elixir" exists with owner "owner@example.com"
    And a huddl "Ash workshop" exists in "Portland Elixir" created by "owner@example.com"
    And I am signed in as "owner@example.com"

  Scenario: Scheduling a huddl highlights the group's huddlz
    When I visit the new huddl page for group "Portland Elixir"
    Then navigation should identify "Huddlz" under group "Portland Elixir" as the current destination

  Scenario: Editing a huddl highlights the group's huddlz
    When I visit the edit page for huddl "Ash workshop"
    Then navigation should identify "Huddlz" under group "Portland Elixir" as the current destination

  Scenario: Editing a group highlights its overview
    When I visit the edit page for group "Portland Elixir"
    Then navigation should identify "Overview" under group "Portland Elixir" as the current destination

  Scenario: Managing locations highlights the group's overview
    When I visit the locations page for "Portland Elixir"
    Then navigation should identify "Overview" under group "Portland Elixir" as the current destination
