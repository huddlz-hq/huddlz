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

  Scenario: An uncounted past row records turnout in place
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    Then the past row for "Elixir hack night" shows "4 RSVPs" and "No turnout yet"
    When I click "Add turnout"
    Then the past row for "Elixir hack night" asks "How many came?"
    When I fill in "People in the room" with "2"
    And I click the "Save turnout" button
    Then the past row for "Elixir hack night" shows "2 in the room" and "50% showed"
    And I am still on the past huddlz list

  Scenario: A virtual row asks for the call
    Given the virtual huddl "Elixir office hours" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    And I click "Add turnout"
    Then the past row for "Elixir office hours" asks "How many joined?"
    And I should not see "People in the room"
    When I fill in "People on the call" with "3"
    And I click the "Save turnout" button
    Then the past row for "Elixir office hours" shows "3 on the call" and "75% showed"

  Scenario: A hybrid row takes both counts
    Given the hybrid huddl "Lightning talks" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    And I click "Add turnout"
    And I fill in "People in the room" with "3"
    And I fill in "People on the call" with "2"
    And I click the "Save turnout" button
    Then the past row for "Lightning talks" shows "3 in the room", "2 on the call" and "125% showed"

  Scenario: Turnout for several huddlz in a row
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended 1 days ago with 4 RSVPs
    And the in-person huddl "Elixir office hours" in "Portland Elixir" ended 2 days ago with 4 RSVPs
    And the in-person huddl "Lightning talks" in "Portland Elixir" ended 3 days ago with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    And I record 2 in the room for "Elixir hack night"
    And I record 3 in the room for "Elixir office hours"
    And I record 4 in the room for "Lightning talks"
    Then the past row for "Elixir hack night" shows "2 in the room" and "50% showed"
    And the past row for "Elixir office hours" shows "3 in the room" and "75% showed"
    And the past row for "Lightning talks" shows "4 in the room" and "100% showed"
    And I am still on the past huddlz list

  Scenario: Editing recorded turnout from the list
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Elixir hack night" was recorded as 2 in the room
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    And I click "Edit turnout"
    And I fill in "People in the room" with "6"
    And I click the "Save turnout" button
    Then the past row for "Elixir hack night" shows "6 in the room" and "150% showed"

  Scenario: An upcoming row offers no turnout action
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" is upcoming with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz"
    Then the row for "Elixir hack night" offers no turnout action

  Scenario: A failed save keeps what was typed
    Given the hybrid huddl "Lightning talks" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    And I click "Add turnout"
    And I fill in "People in the room" with "3"
    And I click the "Save turnout" button
    Then the past row for "Lightning talks" says "how many people were on the call"
    And the "People in the room" field still reads "3"
    And the past row for "Lightning talks" shows "No turnout yet"

  Scenario: The overview nudge records turnout in place
    Given the in-person huddl "Elixir office hours" in "Portland Elixir" ended 3 days ago with 4 RSVPs
    And the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir"
    Then the overview nudge names "Elixir hack night"
    When I click "Add turnout"
    Then the overview nudge asks "How many came?"
    When I fill in "People in the room" with "2"
    And I click the "Save turnout" button
    Then I should see "Turnout saved for Elixir hack night"
    And the overview nudge names "Elixir office hours"
    And the Show rate KPI shows "50%" and "Over 1 counted huddl"
    And I am still on the overview

  Scenario: Skipping from the nudge never asks again
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir"
    And I click "Add turnout"
    And I click the "Skip for now" button
    Then there is no overview nudge
    When I visit "/organize/portland-elixir/huddlz?filter=past"
    Then the past row for "Elixir hack night" shows "No turnout yet"
    And the row for "Elixir hack night" still offers "Add turnout"

  Scenario: The overview nudges about the latest uncounted huddl
    Given the in-person huddl "Elixir office hours" in "Portland Elixir" ended 3 days ago with 4 RSVPs
    And the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    When I visit "/organize/portland-elixir"
    Then the overview nudge names "Elixir hack night"
    And the overview nudge does not name "Elixir office hours"

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
