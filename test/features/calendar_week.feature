@calendar_week @async @database @conn
Feature: Calendar Week view

  Scenario: Week spans Sunday through Saturday in the device time zone
    Given my device time zone is "America/New_York"
    And I am signed in
    And I have Calendar huddlz on the Sunday and Saturday of the current week
    When I select Week in Calendar
    Then the displayed week begins Sunday and ends Saturday in my device time zone
    And I see both huddlz in chronological order

  Scenario: A huddl spanning a week boundary appears in the overlapping week
    Given my device time zone is "America/New_York"
    And I am signed in
    And I have a Calendar huddl that starts before the current week and ends during the current week
    When I select Week in Calendar
    Then I see the huddl once
    And I see its relationship marker

  Scenario: Week state has a stable URL
    Given I am signed in
    When I open Calendar Week for a specific week
    And I copy and revisit the current URL
    Then Calendar shows the same week
    And Week remains selected
