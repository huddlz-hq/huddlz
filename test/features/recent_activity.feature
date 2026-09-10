@database @conn @recent_activity
Feature: Recent activity on the overview
  As an organizer
  I want to see what happened in my group most recently
  So that I notice joins, RSVPs and cancellations as they happen

  Background:
    Given the following users exist:
      | email              | display_name | role    |
      | host@example.com   | Host User    | regular |
      | member@example.com | Member User  | regular |
      | maya@example.com   | Maya Kim     | regular |
      | jordan@example.com | Jordan Tan   | regular |
      | riley@example.com  | Riley Shah   | regular |
      | avery@example.com  | Avery Park   | regular |
      | sam@example.com    | Sam Nguyen   | regular |
    And a public group "Portland Elixir" exists with owner "host@example.com"
    And I am signed in as "host@example.com"

  Scenario: The feed shows the latest activity in order
    Given the huddl "Elixir hack night" was created in "Portland Elixir" last week with room for 2
    And "Jordan Tan" joined "Portland Elixir" yesterday
    And "Riley Shah" RSVPd to "Elixir hack night" 2 days ago
    And "Riley Shah" cancelled their RSVP to "Elixir hack night" 3 hours ago
    And "Maya Kim" RSVPd to "Elixir hack night" 2 hours ago
    And "Avery Park" joined the waitlist for "Elixir hack night" 5 hours ago
    When I visit "/organize/portland-elixir"
    Then the feed lists, newest first:
      | Maya Kim RSVPd to Elixir hack night                  | 2h        |
      | Riley Shah cancelled their RSVP to Elixir hack night | 3h        |
      | Avery Park joined the waitlist for Elixir hack night | 5h        |
      | Jordan Tan joined the group                          | Yesterday |

  Scenario: A cancelled RSVP is remembered
    Given the huddl "Elixir hack night" was created in "Portland Elixir" last week with room for 5
    And "Riley Shah" RSVPd to "Elixir hack night" 2 hours ago
    And "Riley Shah" cancelled their RSVP to "Elixir hack night" 30 minutes ago
    When I visit "/organize/portland-elixir"
    Then the feed shows "Riley Shah cancelled their RSVP to Elixir hack night"
    And the feed shows "Riley Shah RSVPd to Elixir hack night"

  Scenario: A member who left is remembered
    Given "Sam Nguyen" joined "Portland Elixir" 7 days ago
    And "Sam Nguyen" left "Portland Elixir" 10 minutes ago
    When I visit "/organize/portland-elixir"
    Then the feed shows "Sam Nguyen left the group"
    And the feed shows "Sam Nguyen joined the group"

  Scenario: The feed is organizer-only
    Given "member@example.com" is a member of "Portland Elixir"
    When "host@example.com" reads the activity of "Portland Elixir" through GraphQL
    Then the API lists the activity
    When "member@example.com" reads the activity of "Portland Elixir" through GraphQL
    Then the API refuses the activity

  Scenario: The feed links onward
    When I visit "/organize/portland-elixir"
    Then the recent activity panel links to the Members tab
