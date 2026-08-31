@calendar_range_navigation @async @database @conn
Feature: Calendar range navigation

  Scenario: Calendar exposes the supported ranges
    Given I am signed in
    When I visit Calendar
    Then the Calendar ranges are:
      | Day   |
      | Week  |
      | Month |
    And Day is active

  Scenario: I can browse dates within Day
    Given I am viewing Calendar Day
    And I have a Calendar huddl tomorrow
    When I select the next day
    Then I remain in Day
    And I see tomorrow's complete date and huddl count
    And I see the huddl
    And the URL identifies tomorrow
    When I select Today
    Then I return to the current date

  Scenario: Each range has range-specific navigation
    Given I am viewing a selected date in Calendar
    When I use the calendar control
    Then Month opens focused on that date
    And Day resets with Today
    And Week resets with This week
    And Month resets with This month

  Scenario: Coming up supplements only an empty current Day
    Given the current Day is empty
    And I have future Calendar huddlz
    When I visit Calendar Day
    Then I see at most the next three huddlz under Coming up
    When I explicitly select another empty date
    Then I see the normal empty Day state
    And Coming up is not shown
