Feature: Soiree Listing Landing Page
  As a user visiting huddlz.com
  I want to immediately see available soirees
  So that I can understand the platform's value and find events of interest

  Background:
    Given there are upcoming soirees in the system

  Scenario: Viewing the landing page as a visitor
    When I visit the landing page
    Then I should see a list of upcoming soirees
    And I should see basic information for each soiree
    And I should see a search form

  Scenario: Searching for soirees as a visitor
    When I visit the landing page
    And I search for "Elixir"
    Then I should see soirees matching "Elixir"
    When I clear the search form
    Then I should see all upcoming soirees again

  Scenario: Empty search results
    When I visit the landing page
    And I search for "NonExistentTopic"
    Then I should see an empty results message