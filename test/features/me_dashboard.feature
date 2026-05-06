@async @database @conn
Feature: Me dashboard
  As an authenticated user
  I want a tabbed dashboard at /me showing the huddlz I've RSVP'd to,
  am waitlisted for, and have already attended
  So that I can quickly see my own activity without scanning the full discovery feed

  Background:
    Given the following users exist:
      | email                | role     | display_name |
      | host@example.com     | verified | Host User    |
      | attendee@example.com | verified | Attendee     |
      | stranger@example.com | verified | Stranger     |

  Scenario: Anonymous visitor is redirected from /me to sign-in
    When I visit "/me"
    Then I should see "Sign In"

  Scenario: Signed-in user with no activity sees the My Huddlz tab by default with empty sections
    Given I am signed in as "host@example.com"
    When I visit "/me"
    Then I should see "My huddlz."
    And I should see "// Signed in"
    And I should see "Find another huddl"
    And I should see "// Upcoming"
    And I should see "No upcoming RSVPs yet. Find one to attend."
    And I should see "// Waitlisted"
    And I should see "You're not on a waitlist right now."
    And I should see "// Past"
    And I should see "No past attendance yet."

  Scenario: Default tab is My Huddlz when no tab param is given
    Given I am signed in as "host@example.com"
    When I visit "/me"
    Then I should see "// Upcoming"

  Scenario: Unknown tab param falls back to My Huddlz
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=garbage"
    Then I should see "// Upcoming"

  Scenario: My Groups tab shows empty Hosting and Joined sections with side panels
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=groups"
    Then I should see "Groups you organize and groups you've joined."
    And I should see "// Hosting"
    And I should see "You haven't created a group yet."
    And I should see "// Joined"
    And I should see "You haven't joined any groups yet."
    And I should see "// Find more groups"
    And I should see "Discover groups"
    And I should see "// Useful next actions"
    And I should not see "// Upcoming"

  Scenario: Owner sees their group in the Hosting section under My Groups
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/me?tab=groups"
    Then I should see "// Hosting"
    And I should see "Cyberpunk Builders"
    And I should see "You haven't joined any groups yet."

  Scenario: Member sees groups they joined in the Joined section under My Groups
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And "attendee@example.com" has joined the group "Phoenix Devs"
    And I am signed in as "attendee@example.com"
    When I visit "/me?tab=groups"
    Then I should see "// Joined"
    And I should see "Phoenix Devs"
    And I should see "You haven't created a group yet."

  Scenario: Hosting and Joined are split for the same user
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And "host@example.com" has joined the group "Phoenix Devs"
    And I am signed in as "host@example.com"
    When I visit "/me?tab=groups"
    Then I should see "// Hosting"
    And I should see "Cyberpunk Builders"
    And I should see "// Joined"
    And I should see "Phoenix Devs"

  Scenario: Invites tab shows an empty feed with needs-response side panel
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=invites"
    Then I should see "Things that need a response from you."
    And I should see "// Invites"
    And I should see "No invites right now. When organizers invite you to a huddl or group, they'll show up here."
    And I should see "// Needs response"

  Scenario: Being added to a private group surfaces as an Invite
    Given a private group "Phoenix Devs" exists with owner "stranger@example.com"
    And "attendee@example.com" was added to the group "Phoenix Devs"
    And I am signed in as "attendee@example.com"
    When I visit "/me?tab=invites"
    Then I should see "Added to Phoenix Devs"

  Scenario: Updates tab shows an empty feed with notification controls panel
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=updates"
    Then I should see "Reminders, RSVPs, and group activity from across huddlz."
    And I should see "// Updates"
    And I should see "No updates yet. Reminders and group activity will appear here as they happen."
    And I should see "// Notification controls"
    And I should see "Open preferences"

  Scenario: RSVP confirmation appears as a notification on the Updates tab
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And "attendee@example.com" has RSVPed to "Elixir Workshop"
    And I am signed in as "attendee@example.com"
    When I visit "/me?tab=updates"
    Then I should see "RSVP confirmed: Elixir Workshop"
    And I should see "Activity"
    And I should see "Mark all as read"

  Scenario: RSVPed user sees the huddl in the Upcoming section and the Coming up panel
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And "attendee@example.com" has RSVPed to "Elixir Workshop"
    And I am signed in as "attendee@example.com"
    When I visit "/me"
    Then I should see "// Upcoming"
    And I should see "Elixir Workshop"
    And I should see "// Coming up"

  Scenario: Hosting view no longer appears on /me
    Given a public group "Phoenix Devs" exists with owner "host@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/me"
    Then I should not see "// Hosting"
    And I should not see "Elixir Workshop"
