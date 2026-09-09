@database @conn
Feature: Calendar week view and day panel
  As someone with RSVPs
  I want to page through my calendar a week at a time and open any day of the month
  So that I can see the shape of a week and get back to where I was in one step

  Background:
    Given the following users exist:
      | email              | display_name | role    |
      | weekly@example.com | Weekly User  | regular |
    And I am signed in as "weekly@example.com"

  Scenario: The week view draws one week, every day of it
    Given I am going to "Founder Coffee planning call" on day 17 of next month at "08:00"
    And I am going to "Async Rust reading group" on day 24 of next month at "19:00"
    When I open the week of day 17 of next month
    Then every day of that week is drawn
    And the week shows "Founder Coffee planning call" on day 17
    And the week does not list "Async Rust reading group"
    When I move to the next week
    Then the week shows "Async Rust reading group" on day 24
    And the week does not list "Founder Coffee planning call"

  Scenario: A day in the month grid opens its huddlz
    Given I am going to "Elixir office hours" on day 17 of next month at "12:00"
    And I am going to "Hands-on with Ash Framework" on day 17 of next month at "18:30"
    And I am going to "Async Rust reading group" on day 16 of next month at "19:00"
    When I open next month in the month view
    And I open day 17
    Then the day panel lists "Elixir office hours" then "Hands-on with Ash Framework" with their times and places
    And the day panel does not list "Async Rust reading group"
    When I open "Hands-on with Ash Framework" from the day panel
    Then I am on the huddl page for "Hands-on with Ash Framework"

  Scenario: Closing the day panel lands back on the same month
    Given I am going to "Elixir office hours" on day 17 of next month at "12:00"
    When I open next month in the month view
    And I open day 17
    Then the open day is part of the address
    When I close the day panel
    Then I am back on next month in the month view with no day open
