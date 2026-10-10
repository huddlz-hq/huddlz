@async @database @conn @agenda_default_scope
Feature: The agenda opens on my groups
  As a signed-in person who belongs to groups
  I want the agenda to open on everything my groups have scheduled
  So that a huddl I have not RSVP'd to yet is already in front of me

  Background:
    Given the following users exist:
      | email                             | display_name | role    |
      | member+default-scope@example.com  | Member User  | regular |
      | loner+default-scope@example.com   | Loner User   | regular |

  Scenario: The agenda opens on everything my groups have on
    Given I am signed in as "member+default-scope@example.com"
    And I belong to "Default Scope Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And I am going to "Async Rust reading group" with another group
    When I open the agenda
    Then the agenda lists "Hands-on with Ash Framework" without an RSVP status
    And the agenda lists "Async Rust reading group" as going
    And the "Groups" filter is the one I am looking at

  Scenario: My RSVPs are still one click away
    Given I am signed in as "member+default-scope@example.com"
    And I belong to "Default Scope Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And I am going to "Async Rust reading group" with another group
    When I open the agenda
    And I switch to just my RSVPs
    Then the agenda lists "Async Rust reading group" as going
    And the agenda does not list "Hands-on with Ash Framework"
    And the "RSVPs" filter is the one I am looking at

  Scenario: The filter counts stay right whichever filter I am on
    Given I am signed in as "member+default-scope@example.com"
    And "Default Scope Portland Elixir", a group I belong to, has scheduled "Hands-on with Ash Framework" on day 16 of next month
    And my RSVP "Async Rust reading group" is on day 16 of next month
    And my RSVP "Elixir office hours" is on day 24 of next month
    When I open the agenda
    Then the scopes count "RSVPs 2" and "Groups 3"
    When I switch to just my RSVPs
    Then the scopes count "RSVPs 2" and "Groups 3"

  Scenario: A person in no groups is told how to fill the agenda
    Given I am signed in as "loner+default-scope@example.com"
    When I open the agenda
    Then the agenda invites me to find a huddl
