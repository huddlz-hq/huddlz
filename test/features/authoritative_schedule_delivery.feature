@async @database @issue408
Feature: Authoritative schedule delivery

  Scenario: Schedule email uses only the Huddl-local time
    Given my Display time zone is "America/New_York" for schedule delivery
    And a huddl is scheduled for 9:00 AM in "America/Los_Angeles" for schedule delivery
    When I receive its schedule email
    Then the email identifies 9:00 AM with the Pacific abbreviation
    And it contains one schedule time

  Scenario: Calendar export carries the authoritative time zone
    Given a huddl is scheduled in "America/Los_Angeles" for calendar export
    When I receive its calendar attachment
    Then the attachment uses the Huddl TZID
    And it includes a matching VTIMEZONE
    And its schedule resolves to the authoritative Huddl instant
