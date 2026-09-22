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

  Scenario: An organizer cannot edit or remove a connection
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And "organizer@example.com" is an organizer of "Elixir Nashville"
    And I am signed in as "organizer@example.com"
    When I open the Social tab of "Elixir Nashville"
    Then I can see the connection to "#general" but cannot change its schedule or remove it
    And the API refuses my attempt to remove it

  Scenario: A member sees nothing
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And "member@example.com" is a member of "Elixir Nashville"
    And I am signed in as "member@example.com"
    Then I cannot see the social connections of "Elixir Nashville" on the site or the API

  Scenario: Removing a connection
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And I am signed in as "owner@example.com"
    When I remove "#general" from the Social tab of "Elixir Nashville" and confirm
    Then the Social tab of "Elixir Nashville" lists no social connections
    And the activity of "Elixir Nashville" says "Micah Woods removed Slack · #general"

  Scenario: The new owner manages the connections
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And "organizer@example.com" is a member of "Elixir Nashville"
    And ownership of "Elixir Nashville" passes to "organizer@example.com"
    And I am signed in as "organizer@example.com"
    When I open the Social tab of "Elixir Nashville"
    Then I can change the schedule of "#general" and remove it
    And the connection still says it was connected by "Micah Woods"

  Scenario: A private group cannot connect anything
    Given a private group "Inner Circle" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I open the Social tab of "Inner Circle"
    Then the Social tab explains that only public groups post
    And the API refuses a connection for "Inner Circle"

  Scenario: The webhook never leaves the server
    Given "Elixir Nashville" posts to the Slack channel "#general"
    And I am signed in as "owner@example.com"
    When I read the social connections of "Elixir Nashville" through the API
    Then the response names "#general" but carries no webhook address
