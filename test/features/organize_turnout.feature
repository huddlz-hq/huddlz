@database @conn @organize_turnout
Feature: Turnout across Organize
  As an organizer
  I want past huddlz to show how many came, and a reminder when a recent one is uncounted
  So that the numbers I plan with are turnout, not RSVPs

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And I am signed in as "host@example.com"

  Scenario: A counted past row shows turnout and show rate
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Elixir hack night" was recorded as 2 in the room
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    Then the past row for "Elixir hack night" shows "4 RSVPs", "2 in the room" and "50% showed"

  Scenario: A hybrid past row shows both counts
    Given the hybrid huddl "Lightning talks" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Lightning talks" was recorded as 3 in the room and 2 on the call
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    Then the past row for "Lightning talks" shows "3 in the room", "2 on the call" and "125% showed"

  Scenario: An uncounted past row offers Add turnout
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    Then the past row for "Elixir hack night" shows "4 RSVPs" and "No turnout yet"
    When I click "Add turnout"
    Then I should see "How many came?"

  Scenario: The overview nudges about the latest uncounted huddl
    Given the in-person huddl "Elixir office hours" in "Portland Elixir" ended 3 days ago with 4 RSVPs
    And the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir"
    Then the overview nudge names "Elixir hack night"
    And the overview nudge does not name "Elixir office hours"
    When I click "Add turnout"
    Then I should see "How many came?"

  Scenario: A dismissed huddl is not nudged
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout prompt for "Elixir hack night" was skipped
    When I visit "/organize/portland-elixir"
    Then there is no overview nudge

  Scenario: A counted huddl is not nudged
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Elixir hack night" was recorded as 2 in the room
    When I visit "/organize/portland-elixir"
    Then there is no overview nudge

  Scenario: An old huddl is not nudged
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended 15 days ago with 4 RSVPs
    When I visit "/organize/portland-elixir"
    Then there is no overview nudge
