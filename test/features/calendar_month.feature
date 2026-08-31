@calendar_month @async @database @conn
Feature: Calendar Month view

  Scenario: The current month selects the current date and reveals its huddlz
    Given I am signed in
    And I have a Calendar huddl today
    When I select Month in Calendar
    Then I see a Sunday-first grid for the current month
    And the current date is selected
    And I see today's huddl card below the grid

  Scenario: Selecting another day reveals that day's shared cards
    Given I am signed in
    And I have two Calendar huddlz on another day in the displayed month
    When I select Month in Calendar
    And I select that day
    Then I see both huddlz below the grid in chronological order
    And I see each huddl's relationship marker
    And the URL identifies the displayed month and selected day

  Scenario: The month grid is operable accessibly on a narrow viewport
    Given I am signed in
    And I am using a narrow viewport
    When I open Calendar Month
    Then the month grid fits without horizontal page scrolling
    And each day can be reached and selected by keyboard
    And the selected day is exposed to assistive technology
