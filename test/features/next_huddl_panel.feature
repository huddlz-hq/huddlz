@database @conn @next_huddl_panel
Feature: Next huddl panel on the overview
  As an organizer
  I want the overview to show how my next huddl is filling
  So that I can tell at a glance whether to push it or leave it

  Background:
    Given the following users exist:
      | email             | display_name | role    |
      | host@example.com  | Host User    | regular |
      | riley@example.com | Riley Shah   | regular |
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
    And the panel offers no link to more upcoming huddlz

  Scenario: Also upcoming shows only the nearest few
    Given the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 18 RSVPs
    And "Portland Elixir" has 5 more upcoming huddlz called "Study group" a week apart
    When I visit "/organize/portland-elixir"
    Then the panel lists only these other upcoming huddlz:
      | Study group 1 |
      | Study group 2 |
      | Study group 3 |
    And the panel links to all 6 upcoming huddlz

  Scenario: Nothing upcoming
    When I visit "/organize/portland-elixir"
    Then the panel invites me to create a huddl

  Scenario: A cancelled RSVP shows as a rise and a fall
    Given the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 2 RSVPs
    And "Elixir hack night" was published 14 days ago and its RSVPs came in evenly since
    And "Riley Shah" RSVPd to "Elixir hack night" 10 days ago
    And "Riley Shah" cancelled their RSVP to "Elixir hack night" 4 days ago
    When I visit "/organize/portland-elixir"
    Then the next huddl panel shows "2 / 20"
    And the signup curve reads:
      | day 3  | 1 |
      | day 4  | 2 |
      | day 9  | 2 |
      | day 10 | 1 |
      | today  | 2 |

  Scenario: The typical curve remembers cancellations too
    Given "Portland Elixir" has 3 past huddlz
    And "Riley Shah" RSVPd to "Past huddl 1" 20 days ago
    And "Riley Shah" cancelled their RSVP to "Past huddl 1" 17 days ago
    And the huddl "Elixir hack night" in "Portland Elixir" starts in 3 days with room for 20 and 18 RSVPs
    And "Elixir hack night" was published 14 days ago and its RSVPs came in evenly since
    When I visit "/organize/portland-elixir"
    Then the typical curve reads:
      | day 0 | 0.0 |
      | day 1 | 1.3 |
      | day 3 | 3.3 |
      | day 4 | 3.0 |
