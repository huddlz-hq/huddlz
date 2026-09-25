@async @database @conn
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

  @calendar_relative_dates
  Scenario: The agenda counts calendar days rather than full 24-hour periods
    Given I am going to "Day after tomorrow", which starts at midnight two calendar days from today
    When I open the agenda
    Then the agenda times "Day after tomorrow" as "2 days away"

  Scenario: A long huddl still reads as happening now hours after it started
    Given I am going to "All-day sprint", which started 3 hours ago and runs for another 5 hours
    When I open the agenda
    Then the agenda times "All-day sprint" as "happening now"

  Scenario: The week view says a huddl under way is happening now
    Given I am going to "Elixir office hours", which started 20 minutes ago and runs for another 40 minutes
    When I open the week containing "Elixir office hours"
    Then the week times "Elixir office hours" as "happening now"

  Scenario: The day panel says a huddl under way is happening now
    Given I am going to "Elixir office hours", which started 20 minutes ago and runs for another 40 minutes
    When I open the scheduled day for "Elixir office hours" from the month view
    Then the day panel times "Elixir office hours" as "happening now"

  Scenario: A huddl still to come keeps counting down
    Given I am going to "Async Rust reading group", which starts in 90 minutes
    When I open the agenda
    Then the agenda times "Async Rust reading group" as "1 hour away"

  Scenario: The agenda keeps a huddl that started yesterday and is still running
    Given I am going to "Overnight sprint", which started yesterday and is still running
    When I open the agenda
    Then the agenda times "Overnight sprint" as "happening now"
    And the agenda times "Overnight sprint" as "Going"

  Scenario: The week keeps a running overnight huddl's RSVP
    Given I am going to "Overnight sprint", which started yesterday and is still running
    When I open the week containing "Overnight sprint"
    Then the week times "Overnight sprint" as "happening now"
    And the week times "Overnight sprint" as "Going"

  Scenario: The month day panel keeps a running overnight huddl's RSVP
    Given I am going to "Overnight sprint", which started yesterday and is still running
    When I open the scheduled day for "Overnight sprint" from the month view
    Then the day panel times "Overnight sprint" as "happening now"
    And the day panel times "Overnight sprint" as "Going"

  Scenario: A running group huddl without my RSVP is accessible in the month view
    Given my group has "Overnight sprint" running since yesterday without my RSVP
    When I open the month containing "Overnight sprint"
    And I switch to everything from my groups
    Then the calendar announces "Overnight sprint" as "No RSVP"

  Scenario: A running overnight RSVP has the same visible and accessible status
    Given I am going to "Overnight sprint", which started yesterday and is still running
    When I open the month containing "Overnight sprint"
    Then the calendar announces "Overnight sprint" as "Going"
