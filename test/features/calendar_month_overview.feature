@calendar_month_overview @async @database @conn
Feature: Calendar Month overview

  Background:
    Given I am signed in

  Scenario: Month identifies dates that contain relevant huddlz
    Given I have Hosting, Going, Waitlisted, and Group opportunity huddlz on one date
    And I have a cancelled Personal huddl on that date
    When I open Calendar Month
    Then that date shows up to three active relationship indicators
    And it shows +N for the remaining active huddlz
    And the cancelled huddl has a distinct muted indicator
    And the cancelled huddl is excluded from +N
    And the legend explains every indicator

  Scenario: Selecting a Month date reveals its Day contents
    Given I navigated three months into the future
    And I have two Calendar huddlz on a date in that month
    When I select that date
    Then I remain in Month
    And the URL preserves the displayed month and selected date
    And both huddlz appear below the grid chronologically
    And the page moves to the selected Day contents

  Scenario: Month remains usable on a narrow viewport
    Given I am using a narrow viewport
    When I open Calendar Month
    Then the full month fits without horizontal page scrolling
    And each date is keyboard operable
    And indicators and overflow have accessible text
    And selecting an empty date reveals the normal empty Day state
