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

  Scenario: My Groups tab renders a coming-soon placeholder
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=groups"
    Then I should see "Coming soon — joined and organized groups will live here."
    And I should not see "// Upcoming"

  Scenario: Invites tab renders a coming-soon placeholder
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=invites"
    Then I should see "Coming soon — huddl invitations and join requests."

  Scenario: Updates tab renders a coming-soon placeholder
    Given I am signed in as "host@example.com"
    When I visit "/me?tab=updates"
    Then I should see "Coming soon — reminders and announcements."

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
