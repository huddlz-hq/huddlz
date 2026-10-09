@async @database @conn @combined_landing
Feature: One agenda that keeps my intent and offers me somewhere to go
  As a person who signs in — sometimes with one huddl in mind, sometimes with none
  I want signing in to take me where I was headed, and otherwise to open an agenda I can act on
  So that one page answers both arrivals without my having to go looking

  Background:
    Given the following users exist:
      | email                        | display_name | role    |
      | host+combined@example.com    | Combined Host | regular |
      | arrival+combined@example.com | Ada Rivers    | regular |
    And the following group exists:
      | name           | description    | is_public | owner_email               |
      | Combined Pals  | We walk a lot  | true      | host+combined@example.com |
    And the following huddl exists in "Combined Pals":
      | title              | description | event_type | starts_at    | virtual_link           |
      | Combined Dawn Walk | Early start | virtual    | tomorrow 2pm | https://meet.example/g |
    And the user "arrival+combined@example.com" has password "Password123!"

  # The precedence this combination has to settle: A says take me back to the
  # huddl, B says open my chosen filter. They cannot both be the destination.
  Scenario: Arriving for one huddl beats my own agenda preference
    Given "arrival+combined@example.com" opens the agenda on just their RSVPs
    And I start in a signed-out browser
    When I visit the "Combined Dawn Walk" huddl page while signed out
    And I choose "Sign in" in the site header
    And I sign in as "arrival+combined@example.com" with password "Password123!"
    Then I should be on the huddl page for "Combined Dawn Walk"
    And I should see "RSVP to this huddl"

  Scenario: Arriving with nothing in mind opens the filter I chose
    Given "arrival+combined@example.com" opens the agenda on just their RSVPs
    And the user navigates to the sign in page
    When the user enters "arrival+combined@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user lands on their own RSVPs

  # Without a destination and without a preference: the default filter, and a
  # huddl outside my groups reachable from the same page.
  Scenario: Arriving with nothing in mind lands on my groups and still reaches further
    Given "arrival+combined@example.com" has set no agenda preference
    And my home search location is set
    And I belong to "Combined Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    And the user navigates to the sign in page
    When the user enters "arrival+combined@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user lands on everything their groups have on
    And the agenda lists "Hands-on with Ash Framework" without an RSVP status
    When I switch to huddlz near me
    Then the agenda lists "Saturday trail run" without an RSVP status

  # All three filters have to stay reachable from wherever the person lands,
  # or the combination has made one of its own parts unreachable.
  Scenario: Every filter stays one click away from the one I land on
    Given I am signed in as "arrival+combined@example.com"
    And "arrival+combined@example.com" opens the agenda on just their RSVPs
    And my home search location is set
    And I belong to "Combined Portland Elixir", which has scheduled "Hands-on with Ash Framework"
    And I am going to "Async Rust reading group" near my home location
    And a group I have not joined has scheduled "Saturday trail run" near my home location
    When I open the agenda
    Then the "RSVPs" filter is the one I am looking at
    When I switch to everything from my groups
    Then the agenda lists "Hands-on with Ash Framework" without an RSVP status
    When I switch to huddlz near me
    Then the agenda lists "Saturday trail run" without an RSVP status
    When I switch to just my RSVPs
    Then the agenda lists "Async Rust reading group" as going
    And the agenda does not list "Hands-on with Ash Framework"
