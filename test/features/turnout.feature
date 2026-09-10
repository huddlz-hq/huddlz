@database @conn @turnout
Feature: Recording turnout for a past huddl
  As an organizer
  I want to note how many people actually came to a huddl
  So that I can plan the next one on real numbers instead of RSVPs

  Background:
    Given the following users exist:
      | email              | display_name | role    |
      | host@example.com   | Host User    | regular |
      | member@example.com | Member User  | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And "member@example.com" is a member of "Portland Elixir"

  Scenario: Organizer records the room count for an in-person huddl
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should see "How many came?"
    When I fill in "People in the room" with "2"
    And I click the "Save turnout" button
    Then I should see "2 in the room"
    And I should see "50% showed"
    And I should not see "How many came?"

  Scenario: Organizer records the call count for a virtual huddl
    Given the virtual huddl "Elixir office hours" in "Portland Elixir" ended yesterday with 4 RSVPs
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir office hours"
    Then I should see "How many joined?"
    And I should not see "People in the room"
    When I fill in "People on the call" with "3"
    And I click the "Save turnout" button
    Then I should see "3 on the call"
    And I should see "75% showed"

  Scenario: Organizer records both counts for a hybrid huddl
    Given the hybrid huddl "Lightning talks" in "Portland Elixir" ended yesterday with 4 RSVPs
    And I am signed in as "host@example.com"
    When I visit the huddl "Lightning talks"
    And I fill in "People in the room" with "3"
    And I fill in "People on the call" with "2"
    And I click the "Save turnout" button
    Then I should see "3 in the room"
    And I should see "2 on the call"
    And I should see "5 in total"
    And I should see "125% showed"

  Scenario: Skipping never asks again
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "Skip for now" button
    Then I should not see "How many came?"
    And I should see "Turnout not recorded"
    When I visit the huddl "Elixir hack night"
    Then I should not see "How many came?"
    When I click the "Add turnout" button
    And I fill in "People in the room" with "2"
    And I click the "Save turnout" button
    Then I should see "2 in the room"

  Scenario: Editing a recorded count
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Elixir hack night" was recorded as 2 in the room
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "Edit turnout" button
    And I fill in "People in the room" with "6"
    And I click the "Save turnout" button
    Then I should see "6 in the room"
    And I should see "150% showed"

  Scenario: The prompt only appears after the huddl ends
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" is upcoming with 4 RSVPs
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should not see "How many came?"
    And I should not see "Add turnout"

  Scenario: Members never see turnout
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Elixir hack night" was recorded as 2 in the room
    And I am signed in as "member@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should not see "How many came?"
    And I should not see "in the room"
    And I should not see "showed"
    And the API hides the turnout of "Elixir hack night" from "member@example.com"

  Scenario Outline: Recording turnout through the API
    Given the hybrid huddl "Lightning talks" in "Portland Elixir" ended yesterday with 4 RSVPs
    When "host@example.com" records 3 in the room and 2 on the call for "Lightning talks" through "<api>"
    Then the API shows "Lightning talks" with 3 in the room, 2 on the call and a 125% show rate
    When "member@example.com" records 3 in the room and 2 on the call for "Lightning talks" through "<api>"
    Then the API refuses the turnout

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |
