@database @conn
Feature: Calendar agenda grouped by day
  As someone with RSVPs
  I want the agenda to start at today and read as days rather than as rows
  So that I can see what is next without scrolling past what has been

  Background:
    Given the following users exist:
      | email                | display_name | role    |
      | attendee@example.com | Agenda User  | regular |
    And I am signed in as "attendee@example.com"

  Scenario: The month's huddlz are grouped by day in time order
    Given I am going to "Async Rust reading group" on day 16 of next month at "19:00"
    And I am going to "Hands-on with Ash Framework" on day 17 of next month at "18:30"
    And I am going to "Elixir office hours" on day 17 of next month at "12:00"
    When I open the agenda
    Then the agenda shows day 16 with "Async Rust reading group"
    And the agenda shows day 17 with "Elixir office hours" then "Hands-on with Ash Framework"
    And each agenda huddl shows its group and my status

  Scenario: Today anchors the agenda and the past stays in the month view
    Given I have huddlz on the days either side of today
    When I open the agenda
    Then the agenda marks today as having nothing on
    And the agenda does not list "Yesterday's huddl"

  Scenario: The agenda stops after a week of days with huddlz
    Given I am going to a huddl on each of the next 9 days
    When I open the agenda
    Then the agenda lists 7 days of huddlz
    And I am pointed at the month view for the rest
