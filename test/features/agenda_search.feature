@async @database @conn @agenda_search
Feature: Searching for a huddl from the agenda
  As a signed-in person who arrived with one specific huddl in mind
  I want to type its name without leaving my agenda first
  So that a huddl I have not RSVP'd to is one search away, not three clicks away

  Background:
    Given the following users exist:
      | email           | display_name | role    |
      | ada@example.com | Ada Park     | regular |
      | hal@example.com | Hal Rivera   | regular |
    And the following huddlz exist:
      | name                    | group_name       | creator_name |
      | Sourdough Starter Swap  | Fermentation Club | Hal Rivera   |
    And I am signed in as "ada@example.com"

  Scenario: Searching the agenda reaches a huddl I have not RSVP'd to
    When I visit "/agenda"
    Then the agenda does not show "Sourdough Starter Swap"
    When I fill in "Search huddlz" with "Sourdough"
    And I click the "Search" button
    Then I should see "Results for “Sourdough”" as the page heading
    And I should see "Sourdough Starter Swap"

  Scenario: A search with no matches explains itself
    When I visit "/agenda"
    And I fill in "Search huddlz" with "Underwater Bagpiping"
    And I click the "Search" button
    Then I should see "Results for “Underwater Bagpiping”" as the page heading
    And I should see "Nothing matches those filters"

  Scenario: An empty search opens browsing rather than an empty result
    When I visit "/agenda"
    And I click the "Search" button
    Then I should see "Browse huddlz" as the page heading

  Scenario: The agenda gains no filters of its own
    When I visit "/agenda"
    Then the agenda offers one search affordance
    And the agenda offers no date or type filters
