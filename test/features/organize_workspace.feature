@async @database @conn
Feature: Organizer workspace
  As an authenticated organizer
  I want a per-group workspace at /organize/:group_slug
  So that I can manage each group I run on its own terms — overview,
  huddlz, and members — without seeing data from groups I don't own.

  Background:
    Given the following users exist:
      | email                | role     | display_name |
      | host@example.com     | verified | Host User    |
      | attendee@example.com | verified | Attendee     |
      | stranger@example.com | verified | Stranger     |

  Scenario: Anonymous visitor is redirected from /organize to sign-in
    When I visit "/organize"
    Then I should see "Sign in"

  Scenario: Signed-in user with no groups sees the empty-state CTA at /organize
    Given I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "Organizer workspace"
    And I should see "Get started"
    And I should see "You don't organize any groups yet."
    And I should see "Create your first group"

  Scenario: /organize lists owned groups as a picker
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a private group "Inner Circle" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "Your groups"
    And I should see "Cyberpunk Builders"
    And I should see "Inner Circle"
    And I should see "Public"
    And I should see "Private"

  Scenario: /organize picker does not list groups the actor does not own
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "You don't organize any groups yet."
    And I should not see "Phoenix Devs"

  Scenario: /organize picker lists owned groups alphabetically by name
    Given a public group "Synth Society" exists with owner "host@example.com"
    And a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize"
    Then the picker should list "Cyberpunk Builders" before "Synth Society"

  Scenario: Sidebar shows each owned group with sub-tabs when active
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Synth Society" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders"
    Then I should see "Cyberpunk Builders"
    And I should see "Synth Society"
    And I should see "Overview"
    And I should see "Huddlz"
    And I should see "Members"

  Scenario: Visiting another organizer's group slug redirects back to the picker
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/phoenix-devs"
    Then I should see "That group doesn't exist, or you don't organize it."
    And I should see "You don't organize any groups yet."

  Scenario: Visiting an unknown group slug redirects back to the picker with the same flash
    Given I am signed in as "host@example.com"
    When I visit "/organize/no-such-group"
    Then I should see "That group doesn't exist, or you don't organize it."
    And I should see "You don't organize any groups yet."

  Scenario: A co-organizer can open the workspace for a group they help run
    Given the following users exist:
      | email                  | role     | display_name |
      | co.organizer@example.com | verified | Co Organizer |
    And a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And "co.organizer@example.com" is an organizer of "Cyberpunk Builders"
    And I am signed in as "co.organizer@example.com"
    When I visit "/organize/cyberpunk-builders"
    Then I should see "Cyberpunk Builders"
    And I should see "Members"
    And I should not see "That group doesn't exist, or you don't organize it."

  Scenario: An admin can open the workspace for any group
    Given the following users exist:
      | email             | role  | display_name |
      | admin@example.com | admin | Admin User   |
    And a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And I am signed in as "admin@example.com"
    When I visit "/organize/phoenix-devs"
    Then I should see "Phoenix Devs"
    And I should not see "That group doesn't exist, or you don't organize it."

  Scenario: Group overview shows zeroed KPIs and empty upcoming list
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders"
    Then I should see "Cyberpunk Builders"
    And I should see "Members"
    And I should see "Upcoming"
    And I should see "Open RSVPs"
    And I should see "Visibility"
    And I should see "No upcoming huddlz right now. Create one to get started."

  Scenario: Group overview lists the group's upcoming huddl
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders"
    Then I should see "Upcoming huddlz"
    And I should see "Synthwave Night"

  Scenario: Open RSVPs roll up into the overview KPI tile
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And "attendee@example.com" has RSVPed to "Synthwave Night"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders"
    Then I should see "Open RSVPs"
    And I should see "1 RSVP"

  Scenario: Overview does not show huddlz from groups the actor does not organize
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "External Meetup" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders"
    Then I should not see "External Meetup"

  Scenario: Huddlz tab shows the empty state when the group has no live huddlz
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders/huddlz"
    Then I should see "No huddlz scheduled"
    And I should see "Create your first huddl"

  Scenario: Huddlz tab lists live huddlz for the active group
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders/huddlz"
    Then I should see "Live huddlz"
    And I should see "Synthwave Night"

  Scenario: Huddlz tab Past filter lists wrapped huddlz
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the past huddl "Last Year's Demoday" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders/huddlz"
    And I click "Past"
    Then I should see "Past huddlz"
    And I should see "Last Year's Demoday"
    And I should not see "Create your first huddl"

  Scenario: Huddlz tab does not list huddlz from other groups
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Synth Society" exists with owner "host@example.com"
    And the huddl "Modular Jam" exists in group "Synth Society" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders/huddlz"
    Then I should see "No huddlz scheduled"
    And I should not see "Modular Jam"

  Scenario: Huddlz rows link to the huddl edit page
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders/huddlz"
    Then the page should link "Synthwave Night" to its huddl edit screen

  Scenario: Members tab shows the roster grouped by role
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And "attendee@example.com" is a member of "Cyberpunk Builders"
    And I am signed in as "host@example.com"
    When I visit "/organize/cyberpunk-builders/members"
    Then I should see "Owner"
    And I should see "Members"
    And I should see "Co-organizers"
    And I should see "Host User"
    And I should see "Attendee"
    And I should see "No co-organizers yet. Promote a member to organizer to share the load."
