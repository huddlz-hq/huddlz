@async @database @conn
Feature: Huddlz Personal Sections
  As a logged-in user browsing huddlz
  I want to see huddlz I'm hosting or attending surfaced at the top
  So that I can find my own huddlz without scanning the full discovery feed

  Background:
    Given the following users exist:
      | email                | role     | display_name |
      | host@example.com     | verified | Host User    |
      | attendee@example.com | verified | Attendee     |
      | stranger@example.com | verified | Stranger     |

  Scenario: Anonymous users see no personal sections
    Given a public group "Phoenix Devs" exists with owner "host@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "host@example.com"
    When I visit the landing page
    Then I should not see "// Hosting"
    And I should not see "// Attending"

  Scenario: Host sees their huddl in the Hosting section
    Given a public group "Phoenix Devs" exists with owner "host@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit the landing page
    Then I should see "// Hosting"
    And I should see "Elixir Workshop"
    And I should not see "// Attending"

  Scenario: RSVPed user sees the huddl in the Attending section
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "Elixir Workshop" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And "attendee@example.com" has RSVPed to "Elixir Workshop"
    And I am signed in as "attendee@example.com"
    When I visit the landing page
    Then I should see "// Attending"
    And I should not see "// Hosting"

  Scenario: Anonymous user is redirected from a scoped view to sign-in
    When I visit "/?yours=hosting"
    Then I should be redirected to "/sign-in"
    And I should see "Sign in to view huddlz you're hosting"
