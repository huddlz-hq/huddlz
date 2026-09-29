# Keep serial: scenarios stub the platforms' webhooks for the whole test run.
@database @conn @social_steering
Feature: One huddl's social posts can be steered
  The social schedule is the rule; a single huddl sometimes needs an
  exception, a nudge, or a hand-made post somewhere huddlz cannot reach.
  Organizers steer a huddl from its page in the organize workspace.

  Background:
    Given the following users exist:
      | email                 | role     | display_name   |
      | owner@example.com     | verified | Micah Woods    |
      | organizer@example.com | verified | Dana Organizer |
      | member@example.com    | verified | Sam Member     |
    And a public group "Elixir Nashville" exists with owner "owner@example.com"

  Scenario: Seeing what will post for a huddl
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I open "Hack night" in the organize workspace
    Then the Social posts panel lists the week-before and morning-of posts to "#general" with their times

  Scenario: Skipping one huddl on one connection
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" also posts to the Discord channel "#meetups" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I open "Hack night" in the organize workspace
    And I turn off posting it to "#general"
    Then the Social posts panel shows "#general" as skipped for this huddl
    And the Social posts panel lists the morning-of post to "#meetups"
    And the activity of "Elixir Nashville" shows "Micah Woods" skipped "Hack night" on "#general"
    When the morning of "Hack night" arrives
    Then only "#meetups" receives a post

  Scenario: A skipped huddl gets no follow-up there
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    And the week-before post of "Hack night" went out to "#general"
    And "Hack night" is skipped on "#general"
    When I move "Hack night" to the next day
    Then "#general" receives nothing

  Scenario: Unskipping recomputes the posts
    Given "Elixir Nashville" posts to the Slack channel "#general" a week before and the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in three days at 6:00 PM
    And "Hack night" is skipped on "#general"
    And I am signed in as "owner@example.com"
    When I open "Hack night" in the organize workspace
    And I turn posting it to "#general" back on
    Then the Social posts panel lists the morning-of post to "#general"
    But it lists no week-before post

  Scenario: An organizer can skip and post now
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And "organizer@example.com" is an organizer of "Elixir Nashville"
    And I am signed in as "organizer@example.com"
    When I open "Hack night" in the organize workspace
    And I turn off posting it to "#general"
    Then the Social posts panel shows "#general" as skipped for this huddl
    When I turn posting it to "#general" back on
    And I post it now to "#general"
    Then "#general" receives a post about "Hack night"

  Scenario: Post now
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I open "Hack night" in the organize workspace
    And I post it now to "#general"
    Then "#general" receives a post naming "Hack night", its time, its place and its link
    And the Social posts panel lists a post to "#general" as posted now and sent
    And the activity of "Elixir Nashville" shows "Micah Woods" posted "Hack night" to "#general"

  Scenario: Copying the post
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I open "Hack night" in the organize workspace
    Then the post I can copy names "Hack night", its time, its place and its link

  Scenario: A group with no connections still offers the copy
    Given "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I open "Hack night" in the organize workspace
    Then the Social posts panel offers only to copy the post

  Scenario: A private huddl has no panel
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a private huddl "Board meeting" in ten days at 6:00 PM
    And I am signed in as "owner@example.com"
    When I open "Board meeting" in the organize workspace
    Then there is no Social posts panel

  Scenario: Organizers steer a huddl through the API
    Given "Elixir Nashville" posts to the Slack channel "#general" the morning of
    And "Elixir Nashville" has a public huddl "Hack night" in ten days at 6:00 PM
    And "organizer@example.com" is an organizer of "Elixir Nashville"
    And "member@example.com" is a member of "Elixir Nashville"
    When "member@example.com" asks the API to skip "Hack night" on "#general"
    Then the API refuses
    When "organizer@example.com" asks the API to skip "Hack night" on "#general"
    Then the API lists "Hack night" as skipped on "#general" with no posts planned
    When "organizer@example.com" asks the API to unskip "Hack night" on "#general"
    Then the API lists the morning-of post of "Hack night" on "#general"
    When "organizer@example.com" asks the API to post "Hack night" now to "#general"
    Then "#general" receives a post about "Hack night"
