@async @database @conn
Feature: Group Management
  As a verified user or admin
  I want to create and manage groups
  So that I can organize huddlz and connect with others

  Background:
    Given the following users exist:
      | email                    | role     | display_name |
      | admin@example.com        | admin    | Admin User   |
      | verified@example.com     | verified | Verified User|
      | regular@example.com      | regular  | Regular User |

  Scenario: Creating a public group as a verified user
    Given I am signed in as "verified@example.com"
    When I visit "/groups/new"
    Then I should see "Create a group"
    When I fill in the following:
      | Group name  | Tech Enthusiasts           |
      | Description | A group for tech lovers    |
      | Location    | San Francisco, CA          |
    And I check "Public group"
    And I click "Create group"
    Then I should see "Group created successfully"
    And I should see "Tech Enthusiasts"
    And I should see "A group for tech lovers"

  Scenario: Creating a private group as an admin
    Given I am signed in as "admin@example.com"
    When I visit "/groups/new"
    When I fill in the following:
      | Group name  | Secret Society |
      | Description | Private group  |
    And I uncheck "Public group"
    And I click "Create group"
    Then I should see "Group created successfully"
    And I should see "Secret Society"
    And I should see "Private"

  Scenario: Regular users can create groups
    Given I am signed in as "regular@example.com"
    When I visit "/groups/new"
    Then I should see "Create a group"

  Scenario: Viewing a public group as a visitor
    Given a public group "Book Club" exists with owner "verified@example.com"
    When I visit the group page for "Book Club"
    Then I should see "Book Club"
    And the group member count should be 1

  Scenario: Cannot view private group as non-member
    Given a private group "VIP Club" exists with owner "admin@example.com"
    And I am signed in as "regular@example.com"
    When I visit the group page for "VIP Club"
    Then I should be redirected to "/discover?scope=groups"
    And I should see "Group not found"

  Scenario: Owner can edit group details
    Given a public group "Book Club" exists with owner "verified@example.com"
    And I am signed in as "verified@example.com"
    When I visit the group page for "Book Club"
    And I click "Edit Group"
    Then I should see "Edit Group"
    When I fill in the following:
      | Group Name  | Updated Book Club       |
      | Description | Updated description     |
      | Location    | Austin, TX              |
    And I click "Save Changes"
    Then I should see "Group updated successfully"
    And I should see "Updated Book Club"

  Scenario: Owner understands making a public group private
    Given a public group "Book Club" exists with owner "verified@example.com"
    And I am signed in as "verified@example.com"
    When I visit the edit page for "Book Club"
    Then I should see "Current visibility"
    And I should see "Public"
    When I uncheck "Public group"
    Then I should see "Private group"
    And I should see "Access is limited to current members and platform admins"
    And I should see "all existing huddlz will leave public discovery"
    And I should see "Current members keep their memberships"
    When I click "Save Changes"
    Then I should see "Visibility is now private"

  Scenario: Owner understands making a private group public
    Given a private group "Book Club" exists with owner "verified@example.com"
    And I am signed in as "verified@example.com"
    When I visit the edit page for "Book Club"
    Then I should see "Current visibility"
    And I should see "Private"
    When I check "Private group"
    Then I should see "Public group"
    And I should see "Anyone can find and join this group"
    And I should see "otherwise-public huddlz will become discoverable again"
    When I click "Save Changes"
    Then I should see "Visibility is now public"

  Scenario: Non-owner cannot edit group
    Given a public group "Book Club" exists with owner "verified@example.com"
    And I am signed in as "regular@example.com"
    When I visit the edit page for "Book Club"
    Then I should see "You don't have permission to edit this group"

  Scenario: Member confirms before leaving a group
    Given a public group "Book Club" exists with owner "verified@example.com"
    And "regular@example.com" is a member of "Book Club"
    And I am signed in as "regular@example.com"
    When I visit the group page for "Book Club"
    Then the group member count should be 2
    When I click "Leave Group"
    Then I should see the leave dialog for "Book Club"
    When I click "Cancel"
    Then the "Leave Group" button should be visible
    When I click "Leave Group"
    And I click "Yes, leave group"
    Then the "Leave Group" button should not be visible
    And the "Join Group" button should be visible
    And the group member count should be 1
    When I visit "/my-groups"
    Then I should not see "Book Club"

  Scenario: Group name is required
    Given I am signed in as "verified@example.com"
    When I visit "/groups/new"
    And I click "Create group"
    Then I should see an error on the "Group name" field
