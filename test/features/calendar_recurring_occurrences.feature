@calendar_recurring_occurrences @async @database @conn
Feature: Recurring huddl occurrences

  Scenario: Each recurring occurrence appears on its own date
    Given I am an accepted member of a group
    And the group has a published recurring huddl with occurrences this Tuesday and next Tuesday
    When I view each occurrence's week in Calendar
    Then I see the occurrence on the correct Tuesday

  Scenario: An RSVP applies only to the selected occurrence
    Given I am an accepted member of a group
    And the group has a published recurring huddl with occurrences this Tuesday and next Tuesday
    And I am going to this Tuesday's occurrence only
    When I view Calendar Week containing this Tuesday
    Then this Tuesday's occurrence is marked "Going"
    When I view Calendar Week containing next Tuesday
    Then next Tuesday's occurrence has no Personal relationship marker
