@async @database @conn
Feature: Organizer workspace
  As an authenticated organizer
  I want a sidebar-navigated workspace at /organize
  So that I can see my groups and upcoming huddlz at a glance and reach
  the operational tools I'll need as later phases land

  Background:
    Given the following users exist:
      | email                | role     | display_name |
      | host@example.com     | verified | Host User    |
      | attendee@example.com | verified | Attendee     |
      | stranger@example.com | verified | Stranger     |

  Scenario: Anonymous visitor is redirected from /organize to sign-in
    When I visit "/organize"
    Then I should see "Sign In"

  Scenario: Signed-in user with no groups sees the empty-state CTA
    Given I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "Organizer workspace."
    And I should see "// Workspace"
    And I should see "// Get started"
    And I should see "You don't organize any groups yet."
    And I should see "Create your first group"
    And I should not see "// Upcoming huddlz"
    And I should not see "// Open RSVPs"

  Scenario: Sidebar lists every workspace tab
    Given I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "Overview"
    And I should see "Groups"
    And I should see "Huddlz"
    And I should see "Calendar"
    And I should see "Drafts"
    And I should see "Attendees"
    And I should see "Members"
    And I should see "Settings"

  Scenario: Owner with a group but no huddlz sees zeroed metrics and an empty upcoming list
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "// Upcoming huddlz"
    And I should see "// Open RSVPs"
    And I should see "// Groups managed"
    And I should see "No upcoming huddlz right now. Create one to get started."

  Scenario: Owner sees their upcoming huddl on the Overview
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "// Upcoming huddlz"
    And I should see "Synthwave Night"
    And I should see "Cyberpunk Builders"

  Scenario: RSVPs roll up into the Open RSVPs tile
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And "attendee@example.com" has RSVPed to "Synthwave Night"
    And I am signed in as "host@example.com"
    When I visit "/organize"
    Then I should see "// Open RSVPs"
    And I should see "1 RSVP"

  Scenario: Groups tab shows the empty state when the actor owns no groups
    Given I am signed in as "host@example.com"
    When I visit "/organize/groups"
    Then I should see "Manage your groups."
    And I should see "// No groups yet"
    And I should see "You don't organize any groups yet."
    And I should see "Create your first group"

  Scenario: Groups tab lists owned groups with their member count and visibility
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a private group "Inner Circle" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/groups"
    Then I should see "// Groups you organize"
    And I should see "Cyberpunk Builders"
    And I should see "Inner Circle"
    And I should see "Public"
    And I should see "Private"
    And I should see "1 member"

  Scenario: Groups tab does not list groups the actor does not own
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/groups"
    Then I should see "// No groups yet"
    And I should not see "Phoenix Devs"

  Scenario: Group rows link to the group edit page
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/groups"
    Then I should see "Cyberpunk Builders"
    And the page should link "Cyberpunk Builders" to its edit screen

  Scenario: Huddlz tab renders the placeholder card with a link to groups
    Given I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    Then I should see "Huddlz."
    And I should see "// Coming in Phase 3.3"
    And I should see "Browse groups"

  Scenario: Calendar tab renders the placeholder card with no replacement surface
    Given I am signed in as "host@example.com"
    When I visit "/organize/calendar"
    Then I should see "Calendar."
    And I should see "// Coming in Phase 3.8"
    And I should see "No replacement surface available yet."

  Scenario: Drafts tab renders the placeholder card with no replacement surface
    Given I am signed in as "host@example.com"
    When I visit "/organize/drafts"
    Then I should see "Drafts."
    And I should see "// Coming in Phase 3.7"

  Scenario: Attendees tab renders the placeholder card with a link to /me
    Given I am signed in as "host@example.com"
    When I visit "/organize/attendees"
    Then I should see "Attendees."
    And I should see "// Coming in Phase 3.5"

  Scenario: Members tab renders the placeholder card with a link to /me
    Given I am signed in as "host@example.com"
    When I visit "/organize/members"
    Then I should see "Members."
    And I should see "// Coming in Phase 3.6"

  Scenario: Settings tab renders the placeholder card with no replacement surface
    Given I am signed in as "host@example.com"
    When I visit "/organize/settings"
    Then I should see "Settings."
    And I should see "// Coming in Phase 3.9"
