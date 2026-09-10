@database @conn @overview_turnout
Feature: Turnout on the overview
  As an organizer
  I want the overview to show how many people actually come
  So that I plan with turnout, not RSVPs

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And I am signed in as "host@example.com"

  Scenario: Show rate across counted huddlz
    Given 7 counted in-person huddlz in "Portland Elixir" each with 25 RSVPs and 16 in the room
    When I visit "/organize/portland-elixir"
    Then the Show rate KPI shows "64%" and "Over 7 counted huddlz"
    And the show rate sparkline has 7 points

  Scenario: Turnout chart pairs RSVPs with counts
    Given the in-person huddl "Elixir hack night" in "Portland Elixir" ended 3 days ago with 20 RSVPs
    And "Elixir hack night" had room for 20
    And the turnout for "Elixir hack night" was recorded as 11 in the room
    When I visit "/organize/portland-elixir"
    Then the turnout chart pairs "Elixir hack night" as 20 RSVPs and 11 came, with a capacity tick at 20

  Scenario: Hybrid turnout stacks room and call
    Given the hybrid huddl "Lightning talks" in "Portland Elixir" ended 5 days ago with 30 RSVPs
    And the turnout for "Lightning talks" was recorded as 19 in the room and 8 on the call
    When I visit "/organize/portland-elixir"
    Then the turnout bar for "Lightning talks" reads 27 with 19 in the room and 8 on the call

  Scenario: Uncounted huddlz are marked, not hidden
    Given the in-person huddl "Elixir office hours" in "Portland Elixir" ended 2 days ago with 12 RSVPs
    When I visit "/organize/portland-elixir"
    Then the turnout chart shows "Elixir office hours" with 12 RSVPs and an uncounted outline reading "?"

  Scenario: Expected turnout appears with enough history
    Given 3 counted in-person huddlz in "Portland Elixir" each with 20 RSVPs and 12 in the room
    And the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 30 and 18 RSVPs
    When I visit "/organize/portland-elixir"
    Then the Next huddl panel says "expect about 11 in the room"

  Scenario: Expected turnout is hidden without history
    Given 2 counted in-person huddlz in "Portland Elixir" each with 20 RSVPs and 12 in the room
    And the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 30 and 18 RSVPs
    When I visit "/organize/portland-elixir"
    Then the Next huddl panel shows no expectation

  Scenario: No show rate without counts
    Given the in-person huddl "Elixir office hours" in "Portland Elixir" ended 2 days ago with 12 RSVPs
    When I visit "/organize/portland-elixir"
    Then the Show rate KPI reads as not yet available and points at recording turnout
