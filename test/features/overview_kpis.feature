@database @conn @overview_kpis
Feature: Overview KPIs over a period
  As an organizer
  I want the group overview's numbers to move with a chosen period
  So that I can tell whether the group is growing and filling

  Background:
    Given the following users exist:
      | email              | display_name | role    |
      | host@example.com   | Host User    | regular |
      | member@example.com | Member User  | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And "Portland Elixir" was started 3 months ago
    And I am signed in as "host@example.com"

  Scenario: Members KPI shows this month's growth
    Given 4 members joined "Portland Elixir" 2 months ago
    And 2 members joined "Portland Elixir" this month
    When I visit "/organize/portland-elixir"
    Then the Members KPI shows "7" and "+2 this month"

  Scenario: RSVPs KPI compares with the previous period
    Given the huddlz of "Portland Elixir" gathered 3 RSVPs 10 days ago
    And the huddlz of "Portland Elixir" gathered 2 RSVPs 40 days ago
    And the huddlz of "Portland Elixir" gathered 1 RSVP 100 days ago
    When I visit "/organize/portland-elixir"
    Then the RSVPs KPI shows "5" and "+400% vs previous 90 days"

  Scenario: Switching the period changes the figures and the URL
    Given the huddlz of "Portland Elixir" gathered 3 RSVPs 10 days ago
    And the huddlz of "Portland Elixir" gathered 2 RSVPs 40 days ago
    And the huddlz of "Portland Elixir" gathered 1 RSVP 100 days ago
    When I visit "/organize/portland-elixir"
    And I click "30 days"
    Then the RSVPs KPI shows "3" and "+50% vs previous 30 days"
    And the overview URL records the period "30d"
    When I visit "/organize/portland-elixir?period=30d"
    Then the RSVPs KPI shows "3" and "+50% vs previous 30 days"
    When I click "12 months"
    Then the RSVPs KPI shows "6" and "None in the previous 12 months"

  Scenario: Waitlisted now names the full huddl
    Given the huddl "Elixir hack night" exists in group "Portland Elixir" with room for 1 and 1 RSVPs
    And 2 people are waitlisted for "Elixir hack night"
    When I visit "/organize/portland-elixir"
    Then the Waitlisted KPI shows "2" and "Elixir hack night is full"

  Scenario: Sparklines describe their data
    Given 2 members joined "Portland Elixir" this month
    When I visit "/organize/portland-elixir"
    Then the KPI sparklines are inline SVG with readable points

  Scenario: The page still works with no history
    Given a public group "Fresh Group" exists with owner "host@example.com"
    When I visit "/organize/fresh-group"
    Then the Members KPI shows "1" and "+1 this month"
    And the RSVPs KPI shows "0" and "No RSVPs yet"
    And the Waitlisted KPI shows "0" and "No one waiting"

  Scenario: The overview figures are an action organizers can call through the API
    Given 2 members joined "Portland Elixir" this month
    And "member@example.com" is a member of "Portland Elixir"
    When "host@example.com" reads the overview of "Portland Elixir" for "30d" through GraphQL
    Then the API overview shows 4 members and 3 joined this month
    When "member@example.com" reads the overview of "Portland Elixir" for "30d" through GraphQL
    Then the API refuses the overview
