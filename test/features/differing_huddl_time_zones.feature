@async @database @conn
Feature: Differing huddl-local time zones

  Scenario: A traveler can identify the huddl's local time zone
    Given my browser time zone is "America/New_York"
    And I am signed in
    And I am going to a huddl scheduled for 9:00 AM in "America/Los_Angeles"
    When I view the huddl in Calendar
    Then the huddl is placed on the correct day in my browser time zone
    And the card identifies the huddl's local time as "9:00 AM PDT"
