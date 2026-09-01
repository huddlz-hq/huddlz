@async @database @conn @issue405
Feature: Moving a huddl between venue time zones

  Scenario: Moving a huddl preserves its venue-local wall-clock time
    Given a physical huddl is scheduled for 9:00 AM in Miami
    When I move it to a venue in Denver
    Then it remains scheduled for 9:00 AM at the huddl
    And its Huddl time zone becomes "America/Denver"
    And its stored UTC instant is recomputed
    And attendees receive the normal schedule-change notification
