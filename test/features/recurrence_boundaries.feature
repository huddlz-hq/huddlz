@database @conn @recurrence_boundaries
Feature: Organizers can trust recurrence boundaries
  As a group organizer
  I want invalid recurring schedules rejected before publication
  So that members only receive invitations to valid huddlz

  Scenario Outline: Repeat until precedes the first local date
    Given an organizer preparing a recurring huddl for a group with a member
    When the organizer schedules a "<cadence>" huddl ending before its first date
    Then the recurrence form should explain "must be on or after the first huddl date"
    And no huddl, series, or notification should have been created

    Examples:
      | cadence         |
      | Weekly          |
      | Every two weeks |
      | Monthly         |

  Scenario: An invalid whole-series edit leaves the published schedule intact
    Given an organizer preparing a recurring huddl for a group with a member
    And the organizer has published the weekly series
    When the organizer ends the whole series before its first date
    Then the recurrence form should explain "must be on or after the first huddl date"
    And the published series and member notifications should be unchanged

  Scenario: A late-night huddl can end recurrence on its own local date
    Given an organizer preparing a recurring huddl for a group with a member
    When the organizer schedules the huddl ending on its first local date
    Then the published huddl should start on that local date even though UTC is the next day
