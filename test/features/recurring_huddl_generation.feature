@async @database
Feature: Reliable recurring huddl generation
  As a group organizer
  I want every recurring occurrence to retain the series details
  So that attendees can rely on every scheduled date

  Scenario: Weekly virtual huddlz retain the full recurrence contract
    Given a weekly recurring virtual huddl with a cover image
    When its recurring occurrences are generated
    Then two future occurrences should exist
    And every occurrence should retain the virtual huddl details and cover image

  Scenario: Weekly hybrid huddlz retain both locations
    Given a weekly recurring hybrid huddl
    When its recurring occurrences are generated
    Then two future occurrences should exist
    And every occurrence should retain both hybrid locations

  Scenario: Capacity limits apply to every recurring occurrence
    Given a weekly recurring huddl with a capacity of 3
    When its recurring occurrences are generated
    Then every occurrence should have a capacity of 3

  Scenario: Retrying recurring generation does not duplicate occurrences
    Given a weekly recurring huddl
    When its recurring occurrences are generated twice
    Then two future occurrences should exist

  Scenario: The organizer learns when generation ultimately fails
    Given a weekly recurring virtual huddl that cannot generate future occurrences
    When its final recurring generation attempt runs
    Then the organizer should receive a recurring generation failure notification

  Scenario Outline: Monthly huddlz keep the selected day after editing a short month
    Given a monthly huddl on January 31 in <year>
    When its recurring occurrences are generated
    Then its next monthly dates should be "<february>, <march>, <april>"
    When an attendee RSVPs to the March occurrence
    And the organizer renames the whole series from the February occurrence
    Then its next monthly dates should be "<february>, <march>, <april>"
    And the attendee should retain their RSVP to the same March occurrence

    Examples:
      | year | february   | march      | april      |
      | 2028 | 2028-02-29 | 2028-03-31 | 2028-04-30 |
      | 2027 | 2027-02-28 | 2027-03-31 | 2027-04-30 |
