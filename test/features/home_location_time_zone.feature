@home_location_time_zone @async @database @conn
Feature: Home Location time zone

  Scenario: Automatic Display time falls back to my home location
    Given my browser does not provide a valid time zone
    And my saved home location resolves to "America/Chicago"
    When I visit Calendar in Automatic mode
    Then Calendar uses "America/Chicago"

  Scenario: I resolve an unknown home Location time zone explicitly
    Given I select a home location whose time zone cannot be resolved
    When I save my profile
    Then I am asked to choose a valid time zone
    And the home location is not saved without one
