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

  Scenario: The owner sends a test post
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And I am signed in as "owner@example.com"
    When I send a test post to "#general" from the Social tab of "Elixir Nashville"
    Then that channel receives a message saying it is a test from huddlz for "Elixir Nashville"

  Scenario: The owner edits the opening line
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And I am signed in as "owner@example.com"
    When I change the opening line of "#general" to "This week at Elixir Nashville:" from the Social tab of "Elixir Nashville"
    Then the connection to "#general" opens with "This week at Elixir Nashville:" without a save button
    And the activity of "Elixir Nashville" says "Micah Woods changed the schedule for Slack · #general"

  Scenario: An organizer pauses a connection
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And "organizer@example.com" is an organizer of "Elixir Nashville"
    And I am signed in as "organizer@example.com"
    When I pause "#general" from the Social tab of "Elixir Nashville"
    Then the connection shows as paused
    And the activity of "Elixir Nashville" says "Dana Organizer paused Slack · #general"
