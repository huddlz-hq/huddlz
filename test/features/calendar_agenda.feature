@database @conn
Feature: Calendar agenda grouped by day
  As someone with RSVPs
  I want the agenda to read as days rather than as rows
  So that I can see what each day holds and how the month flows

  Background:
    Given the following users exist:
      | email                | display_name | role    |
      | attendee@example.com | Agenda User  | regular |
    And I am signed in as "attendee@example.com"

  Scenario: The month's huddlz are grouped by day in time order
    Given I am going to "Async Rust reading group" on day 16 of next month at "19:00"
    And I am going to "Hands-on with Ash Framework" on day 17 of next month at "18:30"
    And I am going to "Elixir office hours" on day 17 of next month at "12:00"
    When I open next month's agenda
    Then the agenda shows day 16 with "Async Rust reading group"
    And the agenda shows day 17 with "Elixir office hours" then "Hands-on with Ash Framework"
    And each agenda huddl shows its group and my status

  Scenario: Today anchors the agenda even when nothing is on
    Given I have huddlz on the days either side of today
    When I open this month's agenda
    Then the agenda marks today as having nothing on
