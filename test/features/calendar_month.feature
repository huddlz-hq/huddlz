@calendar_month @calendar_month_overview @issue393 @issue401 @async @database @conn
Feature: Calendar Month view

  Background:
    Given I am signed in

  Scenario: The current month selects the current date and reveals its huddlz
    Given I have a Calendar huddl today
    When I select Month in Calendar
    Then I see a Sunday-first grid for the current month
    And the current date is selected
    And I see today's huddl card below the grid

  Scenario: Month identifies dates that contain relevant huddlz
    Given I have Hosting, Going, Waitlisted, and Group opportunity huddlz on one date
    And I have a cancelled Personal huddl on that date
    When I open Calendar Month
    Then that date shows up to three active relationship indicators
    And it shows +N for the remaining active huddlz
    And the cancelled huddl has a distinct muted indicator
    And the cancelled huddl is excluded from +N
    And the legend explains every indicator

  Scenario: Selecting a Month date preserves context and reveals its Day contents
    Given I navigated three months into the future
    And I have two Calendar huddlz on a date in that month
    When I select that date
    Then I remain in Month
    And the URL preserves the displayed month and selected date
    And both huddlz appear below the grid chronologically
    And the page moves to the selected Day contents

  Scenario: Month exposes operable and accessible calendar semantics
    Given I have four Calendar huddlz on one date
    When I open Calendar Month
    Then each date is keyboard operable
    And the selected day is exposed to assistive technology
    And indicators and overflow have accessible text
    And selecting an empty date reveals the normal empty Day state
