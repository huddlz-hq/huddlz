@async @database @conn @agenda_nearby
Feature: Nearby huddlz on the agenda
  As a signed-in person who arrived looking for something to go to
  I want the agenda to offer huddlz near me that I have no relationship to
  So that finding one does not mean leaving the agenda for a separate search page

  Background:
    Given the following users exist:
      | email                      | display_name | role    |
      | nearby+agenda@example.com  | Nora Byrne   | regular |
    And I am signed in as "nearby+agenda@example.com"

  Scenario: The nearby filter shows an upcoming huddl from a group I do not belong to
    Given my home search location is set
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    When I open the agenda
    And I switch to huddlz near me
    Then the agenda lists "Saturday trail run" without an RSVP status

  Scenario: Nearby leaves out huddlz I have already responded to
    Given my home search location is set
    And I am going to "Async Rust reading group" near my home location
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    When I open the agenda
    And I switch to huddlz near me
    Then the agenda lists "Saturday trail run" without an RSVP status
    And the agenda does not list "Async Rust reading group"

  Scenario: Nearby leaves out huddlz too far away to travel to
    Given my home search location is set
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    And a group I have not joined has scheduled "Reykjavik board games" far from my home location
    When I open the agenda
    And I switch to huddlz near me
    Then the agenda lists "Saturday trail run" without an RSVP status
    And the agenda does not list "Reykjavik board games"

  Scenario: Nearby reaches a couple of hours' drive but no further
    Given my home search location is set
    And a group I have not joined has scheduled "Gainesville game night" about 60 miles away
    And a group I have not joined has scheduled "Tampa trivia" about 150 miles away
    When I open the agenda
    And I switch to huddlz near me
    Then the agenda lists "Gainesville game night" without an RSVP status
    And the agenda does not list "Tampa trivia"

  Scenario: The RSVPs and Groups filters still behave as before
    Given my home search location is set
    And I belong to "Nearby Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And I am going to "Async Rust reading group" near my home location
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    When I visit "/agenda?scope=mine"
    Then the agenda lists "Async Rust reading group" as going
    And the agenda does not list "Hands-on with Ash Framework"
    And the agenda does not list "Saturday trail run"
    When I switch to everything from my groups
    Then the agenda lists "Hands-on with Ash Framework" without an RSVP status
    And the agenda lists "Async Rust reading group" as going
    And the agenda does not list "Saturday trail run"

  Scenario: Choosing nearby without a home search location asks for one
    Given I have no home search location
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    When I open the agenda
    And I switch to huddlz near me
    Then the agenda asks me where to look
    And the agenda offers to set my home location
