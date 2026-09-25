@async @database @conn @share_links
Feature: Anyone can share a huddl or group from its page
  huddlz posts to Slack and Discord for a group; everywhere else a person
  shares the link themselves. The Share section on a huddl or group page
  hands them the link and opens the compose screen of the places that have
  one, pre-filled. Sharing is a person sending a link, not a social post.

  Scenario: Offering the huddl link for copying
    Given a public huddl "Community lunch"
    When I open the huddl page
    Then the Share section offers copying the link

  Scenario: Sharing a huddl to a platform
    Given a public huddl "Community lunch" in "America/New_York" on 2030-07-20 at 12:00
    When I open the huddl page
    And I choose to share it on "Bluesky"
    Then the compose screen opens with "Community lunch · Sat, Jul 20, 2030 · 12:00 PM EDT" and the huddl's link

  Scenario: Sharing a group to a platform
    Given a public group "Saturday Cyclists"
    When I open the group page
    And I choose to share it on "X"
    Then the compose screen opens with "Saturday Cyclists" and the group's link

  Scenario: Every place with a compose screen is offered
    Given a public huddl "Community lunch"
    When I open the huddl page
    Then the Share section offers X, Bluesky, Threads, Facebook, LinkedIn and WhatsApp
    And it explains that Instagram and Mastodon take a copied link

  Scenario: Signed-out visitors can share too
    Given a public huddl "Community lunch"
    And I am signed out
    When I open the huddl page
    Then the Share section offers copying the link
    And the Share section offers X, Bluesky, Threads, Facebook, LinkedIn and WhatsApp

  Scenario: A private huddl has no platform links
    Given I am a member of a private group with a huddl "Members' picnic"
    When I open the huddl page
    Then the Share section offers copying the link
    But the Share section offers no platform links

  Scenario: A private group has no platform links
    Given I am a member of a private group with a huddl "Members' picnic"
    When I open the group page
    Then the Share section offers copying the link
    But the Share section offers no platform links
