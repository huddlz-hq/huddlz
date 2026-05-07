@async @database @conn
Feature: Create huddl from organizer workspace
  As an organizer using the /organize workspace
  I want to schedule a new huddl without leaving the sidebar shell
  So that creation feels like part of the workspace flow

  Background:
    Given the following users exist:
      | email             | role     | display_name |
      | host@example.com  | verified | Host User    |

  Scenario: Workspace create form requires at least one owned group
    Given I am signed in as "host@example.com"
    When I visit "/organize/huddlz/new"
    Then I should see "Create a group before scheduling a huddl."
    And I should see "Manage your groups."

  Scenario: Owner sees the workspace create form with sidebar chrome
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz/new"
    Then I should see "// Create huddl"
    And I should see "Schedule a new huddl."
    And I should see "// Workspace"
    And I should see "Which group is this huddl for?"

  Scenario: Group selector lists every group the actor organizes
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Synth Society" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz/new"
    Then I should see "Cyberpunk Builders"
    And I should see "Synth Society"

  Scenario: Workspace Huddlz tab CTA opens the workspace create form
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz"
    And I click "Create your first huddl"
    Then I should see "Schedule a new huddl."
    And I should see "// Create huddl"

  Scenario: Selecting a different group repopulates the form context
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And a public group "Synth Society" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz/new"
    And I select "Synth Society" from "Which group is this huddl for?"
    Then "Synth Society" should be the selected group

  Scenario: Cancelling the workspace create form returns to the Huddlz tab
    Given a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"
    When I visit "/organize/huddlz/new"
    And I click "Cancel"
    Then I should see "Manage your huddlz."
