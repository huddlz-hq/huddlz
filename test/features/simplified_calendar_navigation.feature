@simplified_calendar_navigation @async @database @conn
Feature: Simplified Calendar navigation

  Scenario: The signed-in sidebar uses the simplified primary navigation
    Given I am signed in
    And I organize a group named "Code and Coffee"
    When I open the application sidebar
    Then the primary navigation contains only "Discover", "Calendar", and "Groups"
    And Calendar has no count badge
    And "Code and Coffee" appears in a visually separate "Organize" section

  Scenario: Calendar opens the current Day
    Given I am signed in
    When I open the application sidebar
    And I choose Calendar from the primary navigation
    Then the current date is selected
    And Calendar is the active primary destination

  Scenario: The legacy My huddlz route enters Calendar safely
    Given I am signed in
    When I visit the legacy My huddlz URL
    Then I am taken to Calendar
    And the current date is selected
