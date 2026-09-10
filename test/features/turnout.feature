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

  Scenario: Organizers read turnout on the huddl page and record it in Organize
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And the turnout for "Elixir hack night" was recorded as 2 in the room
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should see "2 in the room"
    And I should see "50% showed"
    And I should not see "Save turnout"
    And I should not see "Edit turnout"

  Scenario: An uncounted huddl page points at Organize
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended yesterday with 4 RSVPs
    And I am signed in as "host@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should see "Turnout not recorded"
    And I should not see "How many came?"
    When I click link "Record it in Organize"
    Then I should see "Add turnout"

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
