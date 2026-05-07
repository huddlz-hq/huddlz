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

  Scenario: Huddlz tab shows the empty state when the actor has no live huddlz
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    Then I should see "Manage your huddlz."
    And I should see "// No live huddlz"
    And I should see "Nothing on the calendar."
    And I should see "Create your first huddl"

  Scenario: Huddlz tab lists live huddlz across every group the actor organizes
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Synth Society" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And the huddl "Modular Jam" exists in group "Synth Society" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    Then I should see "// Live huddlz"
    And I should see "Synthwave Night"
    And I should see "Modular Jam"
    And I should see "Cyberpunk Builders"
    And I should see "Synth Society"

  Scenario: Huddlz tab Past filter lists wrapped huddlz
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the past huddl "Last Year's Demoday" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    And I click "Past"
    Then I should see "// Past huddlz"
    And I should see "Last Year's Demoday"
    And I should not see "Create your first huddl"

  Scenario: Huddlz tab does not list huddlz from groups the actor does not organize
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "External Meetup" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    Then I should see "// No live huddlz"
    And I should not see "External Meetup"

  Scenario: Huddlz tab rows link to the huddl edit page
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    Then the page should link "Synthwave Night" to its huddl edit screen

  Scenario: Calendar tab renders the placeholder card with no replacement surface
    Given I am signed in as "host@example.com"
    When I visit "/organize/calendar"
    Then I should see "Calendar."
    And I should see "// Coming in Phase 3.8"
    And I should see "No replacement surface available yet."

  Scenario: Attendees tab shows the empty state when the actor has no upcoming huddlz
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/attendees"
    Then I should see "Track attendees."
    And I should see "// No upcoming huddlz"
    And I should see "Nothing on the calendar."

  Scenario: Attendees tab lists upcoming huddlz with RSVP and waitlist counts
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And "attendee@example.com" has RSVPed to "Synthwave Night"
    And I am signed in as "host@example.com"
    When I visit "/organize/attendees"
    Then I should see "// Upcoming huddlz"
    And I should see "Synthwave Night"
    And I should see "1 RSVP"
    And I should see "0 waitlist"

  Scenario: Attendees tab does not list huddlz from groups the actor does not organize
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And the huddl "External Meetup" exists in group "Phoenix Devs" hosted by "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/attendees"
    Then I should see "// No upcoming huddlz"
    And I should not see "External Meetup"

  Scenario: Selecting a huddl shows its attendees in the detail view
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And the huddl "Synthwave Night" exists in group "Cyberpunk Builders" hosted by "host@example.com"
    And "attendee@example.com" has RSVPed to "Synthwave Night"
    And I am signed in as "host@example.com"
    When I visit "/organize/attendees"
    And I click "Synthwave Night"
    Then I should see "// Attending"
    And I should see "// Waitlist"
    And I should see "Attendee"
    And I should see "Nobody is on the waitlist."
    And I should see "All upcoming"

  Scenario: Members tab shows the empty state when the actor owns no groups
    Given I am signed in as "host@example.com"
    When I visit "/organize/members"
    Then I should see "Understand members."
    And I should see "// No groups yet"
    And I should see "You don't own any groups yet."

  Scenario: Members tab lists groups the actor owns with member counts
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a private group "Inner Circle" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/members"
    Then I should see "// Your groups"
    And I should see "Cyberpunk Builders"
    And I should see "Inner Circle"
    And I should see "Public"
    And I should see "Private"

  Scenario: Members tab does not list groups the actor does not own
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/members"
    Then I should see "// No groups yet"
    And I should not see "Phoenix Devs"

  Scenario: Selecting a group shows its roster grouped by role
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And "attendee@example.com" is a member of "Cyberpunk Builders"
    And I am signed in as "host@example.com"
    When I visit "/organize/members"
    And I click "Cyberpunk Builders"
    Then I should see "// Owner"
    And I should see "// Members"
    And I should see "// Organizers"
    And I should see "Host User"
    And I should see "Attendee"
    And I should see "All groups"
    And I should see "No co-organizers yet."

  Scenario: Settings tab renders the placeholder card with no replacement surface
    Given I am signed in as "host@example.com"
    When I visit "/organize/settings"
    Then I should see "Settings."
    And I should see "// Coming in Phase 3.9"
