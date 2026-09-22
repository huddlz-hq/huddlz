@database @conn @share_links
Feature: Anyone can share a huddl or group from its page
  huddlz posts to Slack and Discord for a group; everywhere else a person
  shares the link themselves. The Share section on a huddl or group page
  hands them the link and opens the compose screen of the places that have
  one, pre-filled. Sharing is a person sending a link, not a social post.

  Scenario: Copying the huddl link
    Given a public huddl "Community lunch"
    When I open the huddl page
    Then I can copy the huddl's link from the Share section

  Scenario: Sharing a huddl to a platform
    Given a public huddl "Community lunch" in "America/New_York" on 2030-07-20 at 12:00
    When I open the huddl page
    And I choose to share it on "Bluesky"
    Then the compose screen opens with "Community lunch · Sat, Jul 20, 2030 · 12:00 PM EDT" and the huddl's link
