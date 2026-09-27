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
      | member@example.com    | verified | Sam Member     |
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

  Scenario: A moment that has passed is skipped
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And I am signed in as "owner@example.com"
    When I publish a public huddl "Hack night" three days from now
    Then the Social tab of "Elixir Nashville" lists the morning-of post of "Hack night" as upcoming
    But it lists no week-before post of "Hack night"

  Scenario: A private huddl is never posted
    Given "Elixir Nashville" posts to the Slack channel "#general" when a huddl is published and the morning of
    And I am signed in as "owner@example.com"
    When I publish a private huddl "Board meeting" next week
    Then "#general" receives nothing
    And the upcoming posts on the Social tab of "Elixir Nashville" do not mention "Board meeting"

  Scenario: Organizers can read upcoming posts through the API
    Given "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "organizer@example.com" is an organizer of "Elixir Nashville"
    And "member@example.com" is a member of "Elixir Nashville"
    When "organizer@example.com" asks the API for the upcoming social posts of "Elixir Nashville"
    Then the answer lists the week-before and morning-of posts of "Hack night" with their times
    When "member@example.com" asks the API for the upcoming social posts of "Elixir Nashville"
    Then the answer lists no posts

  Scenario: A paused connection posts nothing
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    And "#general" is paused
    When the morning of "Hack night" arrives
    Then "#general" receives nothing
    When "#general" is resumed
    Then "#general" receives nothing

  Scenario: A series posts once when published
    Given "Elixir Nashville" posts to the Slack channel "#general" when a huddl is published
    And I am signed in as "owner@example.com"
    When I publish "Hack night" every Thursday at 6:00 PM for twelve weeks
    Then "#general" receives one post saying "Every Thursday at 6:00 PM" and linking to the first "Hack night"

  Scenario: Each huddl in a series gets its own timed posts
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And I am signed in as "owner@example.com"
    And I publish "Hack night" every Thursday at 6:00 PM for four weeks
    When the morning of the second "Hack night" arrives
    Then "#general" receives a post saying the second "Hack night" is today at 6:00 PM

  Scenario: A cancelled huddl gets a follow-up
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    And the week-before post of "Hack night" went out to "#general"
    When I cancel "Hack night"
    Then "#general" receives a post saying "Hack night" is cancelled
    And the upcoming posts on the Social tab of "Elixir Nashville" do not mention "Hack night"

  Scenario: A moved huddl gets a follow-up
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    And the week-before post of "Hack night" went out to "#general"
    When I move "Hack night" to the next day
    Then "#general" receives a post giving the new time of "Hack night" and the old one
    When the morning of "Hack night" arrives
    Then "#general" receives a post saying "Hack night" is today at 6:00 PM

  Scenario: A huddl that was never posted gets no follow-up
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I cancel "Hack night"
    Then "#general" receives nothing

  Scenario: The platform refuses the post
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When Slack refuses the morning-of post of "Hack night" because the connection was revoked
    Then the Social tab of "Elixir Nashville" shows "#general" as needing reconnecting
    And it lists the morning-of post of "Hack night" as not sent
    And "owner@example.com" is emailed that posts to "#general" stopped while posting "Hack night"

  Scenario: A passing failure does not break the connection
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When Slack fails once and then accepts the morning-of post of "Hack night"
    Then "#general" receives a post saying "Hack night" is today at 6:00 PM
    And the Social tab of "Elixir Nashville" shows "#general" as posting
    And nobody is emailed about "#general"

  Scenario: A post that keeps failing is listed as not sent
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When Slack keeps failing the morning-of post of "Hack night"
    Then the Social tab of "Elixir Nashville" shows "#general" as posting
    And it lists the morning-of post of "Hack night" as not sent
    And nobody is emailed about "#general"
