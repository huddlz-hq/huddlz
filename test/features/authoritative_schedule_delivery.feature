@async @database @issue408
Feature: Authoritative schedule delivery

  Scenario: Schedule email uses only the authoritative huddl time
    Given my Calendar time zone is "America/New_York" for schedule delivery
    And a huddl is scheduled for 9:00 AM in "America/Los_Angeles" for schedule delivery
    When I receive its schedule email
    Then the email identifies 9:00 AM with the Pacific abbreviation
    And it contains one schedule time

  Scenario: A physical venue schedule exports as the correct UTC instant
    Given a physical huddl is scheduled for 9:00 AM at a venue resolved to "America/Los_Angeles"
    When I receive its calendar attachment
    Then the physical huddl keeps the venue time zone and correct UTC instant
    And the attachment carries that schedule as UTC timestamps
    And its schedule resolves to the authoritative Huddl instant
