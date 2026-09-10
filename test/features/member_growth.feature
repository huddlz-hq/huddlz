@database @conn @member_growth
Feature: Member growth on the overview
  As an organizer
  I want to see how the group has grown over the period
  So that I can tell whether it is gaining members steadily

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
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
