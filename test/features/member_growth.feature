@database @conn @member_growth
Feature: Member growth on the overview
  As an organizer
  I want to see how the group has grown over the period
  So that I can tell whether it is gaining members steadily

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
      | sam@example.com  | Sam Nguyen   | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And I am signed in as "host@example.com"

  Scenario: Growth over twelve months
    Given 5 members joined "Portland Elixir" 20 months ago
    And 2 members joined "Portland Elixir" in each of the last 6 months
    When I visit "/organize/portland-elixir?period=12m"
    Then the growth chart shows a point per month ending this month at 18 members with 3 joined
    And the growth panel head shows "+13" gained in "12 months"

  Scenario: A short period buckets by week
    Given 2 members joined "Portland Elixir" in each of the last 6 months
    When I visit "/organize/portland-elixir"
    And I click "30 days"
    Then the growth chart shows one bucket per week
    When I click "90 days"
    Then the growth chart shows one bucket per fortnight

  Scenario: Months with no joins still appear
    Given 2 members joined "Portland Elixir" in each of the last 6 months
    But nobody joined "Portland Elixir" 3 months ago
    When I visit "/organize/portland-elixir?period=12m"
    Then the month 3 months ago shows a zero bar and the line stays flat at 4 through it

  Scenario: A leave shows as a dip
    Given 2 members joined "Portland Elixir" in each of the last 6 months
    And "Sam Nguyen" joined "Portland Elixir" 4 months ago and left 2 months ago
    When I visit "/organize/portland-elixir?period=12m"
    Then the month 2 months ago shows 2 joined and 1 left, and the line stands at 8 after it
    And the growth panel head shows "+13" net in "12 months" from "14 joined" and "1 left"

  Scenario: Without leaves nothing changes
    Given 2 members joined "Portland Elixir" in each of the last 6 months
    When I visit "/organize/portland-elixir?period=12m"
    Then the growth panel head shows "+13" gained in "12 months"
    And no month shows anyone leaving

  Scenario: Rejoining preserves the earlier membership
    Given "Sam Nguyen" joined "Portland Elixir" 4 months ago and left 2 months ago
    And "Sam Nguyen" rejoined "Portland Elixir" 1 month ago
    When I visit "/organize/portland-elixir?period=12m"
    Then the growth panel head shows "+2" net in "12 months" from "3 joined" and "1 left"
    And the month 2 months ago shows 0 joined and 1 left, and the line stands at 0 after it
    And the month 6 months ago shows a zero bar and the line stays flat at 0 through it
    And the Members sparkline starts at 0, dips from 1 to 0, and ends at 2

  Scenario: Accepting an invitation while already a member does not add another join
    Given a private group "Portland Friends" exists with owner "host@example.com"
    And "Sam Nguyen" was added to "Portland Friends" 4 months ago, accepted an invitation 3 months ago and left 2 months ago
    When I visit "/organize/portland-friends?period=12m"
    Then the growth panel head shows "+1" net in "12 months" from "2 joined" and "1 left"
    And the month 3 months ago shows a zero bar and the line stays flat at 1 through it
    And the month 2 months ago shows 0 joined and 1 left, and the line stands at 0 after it
    And the Members sparkline starts at 0, dips from 1 to 0, and ends at 1
