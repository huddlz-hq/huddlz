@calendar_time_zone @async @database @conn
Feature: Calendar time-zone preference

  @automatic_time_zone_label
  Scenario: Automatic Calendar time uses the browser time zone
    Given my Calendar time-zone mode is Automatic
    And my browser time zone is "America/Los_Angeles"
    When I visit Calendar
    Then Calendar uses "America/Los_Angeles"
    And Automatic shows "America/Los_Angeles"

  @automatic_time_zone_label
  Scenario: Automatic previews its resolved time zone while Fixed is selected
    Given my Calendar time-zone mode is Automatic
    And my browser time zone is "America/Los_Angeles"
    When I visit Calendar
    And I select Fixed "America/Denver"
    Then Automatic shows "America/Los_Angeles"

  Scenario: A Fixed Calendar time zone persists
    Given I am viewing Calendar
    When I select Fixed "America/Denver"
    Then Calendar uses "America/Denver"
    And the choice remains after I sign in on another device

  Scenario: Automatic mode has a deterministic final fallback
    Given my Calendar time-zone mode is Automatic
    And no valid browser or home Location time zone is available
    When I visit Calendar
    Then Calendar uses "America/New_York"
