# Keep serial: scenarios stub the platforms' webhooks for the whole test run.
@database @conn @social_schedule
Feature: Huddlz are posted on each connection's social schedule
  The point of a social connection is that nobody has to remember to post.
  Each connection carries its own social schedule and every public huddl
  follows it.

  Background:
    Given the following users exist:
      | email                 | role     | display_name   |
      | owner@example.com     | verified | Micah Woods    |
      | organizer@example.com | verified | Dana Organizer |
    And a public group "Elixir Nashville" exists with owner "owner@example.com"

  Scenario: A huddl is posted a week before and the morning of
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    When the week-before moment of "Hack night" arrives
    Then "#general" receives a post naming "Hack night", its time, its place and its link
    When the morning of "Hack night" arrives
    Then "#general" receives a post saying "Hack night" is today at 6:00 PM

  Scenario: The opening line leads the post
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of, opening with "This week at Elixir Nashville:"
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    When the morning of "Hack night" arrives
    Then the post to "#general" begins with "This week at Elixir Nashville:"

  Scenario: A full huddl still posts
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And every spot at "Hack night" is taken and someone is on the waitlist
    When the morning of "Hack night" arrives
    Then "#general" receives a post saying "Hack night" is full and the waitlist is open

  Scenario: Publishing posts right away
    Given "Elixir Nashville" posts to the Slack channel "#general" when a huddl is published
    And I am signed in as "owner@example.com"
    When I publish a public huddl "Hack night" next week
    Then "#general" receives a post about "Hack night"
