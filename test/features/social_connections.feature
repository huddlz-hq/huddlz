@database @conn @social_connections
Feature: A group connects a place for huddlz to post to
  Organizers paste a link to each huddl into their Slack by hand. A social
  connection is the group's link to one outside place, set up once by the
  owner, so huddlz can post there on the group's behalf. Only public groups
  have them.

  Background:
    Given the following users exist:
      | email                 | role     | display_name   |
      | owner@example.com     | verified | Micah Woods    |
      | organizer@example.com | verified | Dana Organizer |
      | member@example.com    | verified | Sam Member     |
    And a public group "Elixir Nashville" exists with owner "owner@example.com"

  Scenario: The owner connects a Slack channel
    Given I am signed in as "owner@example.com"
    When I connect the Slack channel "#general" of "Elixir Nashville HQ" from the Social tab of "Elixir Nashville"
    Then the Social tab lists a connection to "#general" on Slack
    And the connection shows as posting
    And the activity of "Elixir Nashville" says "Micah Woods connected Slack · #general"

  Scenario: The owner connects a second channel on Discord
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And I am signed in as "owner@example.com"
    When I connect the Discord channel "#meetups" of "Music City Makers" from the Social tab of "Elixir Nashville"
    Then the Social tab lists a connection to "#general" on Slack
    And the Social tab lists a connection to "#meetups" on Discord
