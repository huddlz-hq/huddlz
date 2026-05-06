@async @database @conn
Feature: Me dashboard
  As an authenticated user
  I want a dashboard at /me showing the huddlz I host and attend
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

  Scenario: Signed-in user with no activity sees empty states for both sections
    Given I am signed in as "host@example.com"
    When I visit "/me"
    Then I should see "Welcome back, Host."
    And I should see "// Hosting"
    And I should see "You aren't hosting any upcoming huddlz."
    And I should see "// Attending"
    And I should see "You haven't RSVP'd to any upcoming huddlz."

  Scenario: Host sees their huddl in the Hosting section
    Given a public group "Phoenix Devs" exists with owner "host@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/me"
    Then I should see "// Hosting"
    And I should see "Elixir Workshop"

  Scenario: RSVPed user sees the huddl in the Attending section
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And "attendee@example.com" has RSVPed to "Elixir Workshop"
    And I am signed in as "attendee@example.com"
    When I visit "/me"
    Then I should see "// Attending"
    And I should see "Elixir Workshop"
