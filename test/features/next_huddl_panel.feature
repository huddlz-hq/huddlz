@database @conn @next_huddl_panel
Feature: Next huddl panel on the overview
  As an organizer
  I want the overview to show how my next huddl is filling
  So that I can tell at a glance whether to push it or leave it

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And I am signed in as "host@example.com"

  Scenario: The next huddl's signup curve
    Given the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 18 RSVPs
    And "Elixir hack night" was published 14 days ago and its RSVPs came in evenly since
    When I visit "/organize/portland-elixir"
    Then the next huddl panel names "Elixir hack night"
    And the next huddl panel shows "18 / 20"
    And the signup curve has one point per day for 14 days and ends at 18
    And the signup chart marks the capacity of 20
    And I should not see "Upcoming huddlz"

  Scenario: The typical curve appears with enough history
    Given "Portland Elixir" has 3 past huddlz
    And the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 18 RSVPs
    And "Elixir hack night" was published 14 days ago and its RSVPs came in evenly since
    When I visit "/organize/portland-elixir"
    Then the panel also draws the group's typical curve

  Scenario: No typical curve without history
    Given "Portland Elixir" has 2 past huddlz
    And the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 18 RSVPs
    And "Elixir hack night" was published 14 days ago and its RSVPs came in evenly since
    When I visit "/organize/portland-elixir"
    Then only the huddl's own curve is drawn

  Scenario: Other upcoming huddlz are listed
    Given the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 18 RSVPs
    And the huddl "Elixir office hours" in "Portland Elixir" starts in 10 days with room for 20 and 8 RSVPs
    And the huddl "Phoenix workshop" in "Portland Elixir" starts in 17 days with room for 1 and 1 RSVPs
    And 6 people are waitlisted for "Phoenix workshop"
    When I visit "/organize/portland-elixir"
    Then the next huddl panel names "Elixir hack night"
    And the panel lists the other upcoming huddl "Elixir office hours · 8 / 20"
    And the panel lists the other upcoming huddl "Phoenix workshop · 1 / 1 · 6 waitlisted"

  Scenario: Nothing upcoming
    When I visit "/organize/portland-elixir"
    Then the panel invites me to create a huddl
