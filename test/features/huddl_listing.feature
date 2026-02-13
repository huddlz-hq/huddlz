@async @database @conn
Feature: Huddl Listing
  As a visitor to the website
  I want to see a list of upcoming huddls
  So that I can discover events that interest me

  Background:
    Given there are upcoming huddlz in the system

  Scenario: View huddl listing on landing page
    When I visit the landing page
    Then I should see a list of upcoming huddlz
    And I should see basic information for each huddl
    And I should see a search form

  Scenario: Search for huddlz
    When I visit the landing page
    And I search for "Elixir"
    Then I should see huddlz matching "Elixir"

  Scenario: Clear search
    When I visit the landing page
    And I search for "something"
    And I clear the search form
    Then I should see all upcoming huddlz again

  Scenario: Search by location with autocomplete
    When I visit the landing page
    And I type "aus" in the location field
    Then I should see location suggestions
    When I select "Austin" from the location suggestions
    Then the location filter should be active with "Austin, TX, USA"

  Scenario: No location suggestions for gibberish
    When I visit the landing page
    And I type "xyznonexistent" in the location field
    Then I should see "No locations found"

  Scenario: Clear location filter
    When I visit the landing page
    And I type "aus" in the location field
    And I select "Austin" from the location suggestions
    And I clear the search form
    Then the location filter should not be active
