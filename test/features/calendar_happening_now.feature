@database @conn
Feature: Huddlz that are happening now on the agenda and calendar
  As someone with an RSVP to a huddl that has already started
  I want the agenda and the calendar to say it is happening now
  So that I do not think I have missed something I could still join

  Background:
    Given the following users exist:
      | email               | display_name | role    |
      | joining@example.com | Joining User | regular |
    And I am signed in as "joining@example.com"

  Scenario: The agenda says a huddl under way is happening now
    Given I am going to "Elixir office hours", which started 20 minutes ago and runs for another 40 minutes
    When I open the agenda
    Then the agenda times "Elixir office hours" as "happening now"

  Scenario: A long huddl still reads as happening now hours after it started
    Given I am going to "All-day sprint", which started 3 hours ago and runs for another 5 hours
    When I open the agenda
    Then the agenda times "All-day sprint" as "happening now"

  Scenario: The week view says a huddl under way is happening now
    Given I am going to "Elixir office hours", which started 20 minutes ago and runs for another 40 minutes
    When I open this week
    Then the week times "Elixir office hours" as "happening now"

  Scenario: The day panel says a huddl under way is happening now
    Given I am going to "Elixir office hours", which started 20 minutes ago and runs for another 40 minutes
    When I open today from the month view
    Then the day panel times "Elixir office hours" as "happening now"

  Scenario: A huddl still to come keeps counting down
    Given I am going to "Async Rust reading group", which starts in 90 minutes
    When I open the agenda
    Then the agenda times "Async Rust reading group" as "1 hour away"
