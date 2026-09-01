@simplified_calendar_navigation @async @database @conn
Feature: Simplified Calendar navigation

  Scenario: The signed-in sidebar uses the simplified primary navigation
    Given I am signed in
    And I organize a group named "Code and Coffee"
    When I open the application sidebar
    Then the primary navigation contains "Discover", "Today", "Calendar", and "Groups"
    And the primary navigation does not contain "My huddlz" or "My calendar"
    And Calendar has no count badge
    And "Code and Coffee" appears in a visually separate "Organize" section

  Scenario: Today opens the current Calendar Day
    Given I am signed in
    When I open the application sidebar
    And I choose Today from the primary navigation
    Then the current date is selected
    And Today is the active primary destination

  Scenario: Calendar opens the current Month
    Given I am signed in
    When I open the application sidebar
    And I choose Calendar from the primary navigation
    Then Month is the active Calendar range
    And Calendar is the active primary destination

  Scenario: The legacy My huddlz route enters Calendar safely
    Given I am signed in
    When I visit the legacy My huddlz URL
    Then I am taken to Calendar
    And the current date is selected

  Scenario: The global Discover search keeps its existing behavior
    Given I am signed in
    And I am viewing Calendar
    When I use the global Discover search
    Then I am taken to Discover search results using the existing search behavior
