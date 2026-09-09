@database @conn
Feature: Calendar scope: my RSVPs or everything my groups have on
  As a member of active groups
  I want the calendar to show everything my groups have scheduled, not only what I have responded to
  So that I can see what to join next without opening each group

  Background:
    Given the following users exist:
      | email               | display_name | role    |
      | member@example.com  | Member User  | regular |
    And I am signed in as "member@example.com"

  Scenario: The calendar starts with what I have responded to
    Given I belong to "Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And I am going to "Async Rust reading group" with another group
    When I open the agenda
    Then the calendar offers "RSVPs" and "Groups" scopes
    And the agenda lists "Async Rust reading group" as going
    And the agenda does not list "Hands-on with Ash Framework"

  Scenario: Everything my groups have on
    Given I belong to "Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And I am going to "Async Rust reading group" with another group
    And a group I have not joined has scheduled "Not for me"
    When I open the agenda
    And I switch to everything from my groups
    Then the agenda lists "Hands-on with Ash Framework" without an RSVP status
    And the agenda lists "Async Rust reading group" as going
    And the agenda does not list "Not for me"
