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

  Scenario: Viewing groups page as a visitor
    When I visit the groups page
    Then I should see "Groups"
    And I should see "No groups found"
    And I should not see "New Group"

  Scenario: Viewing groups page as a regular user
    Given I am signed in as "regular@example.com"
    When I visit the groups page
    Then I should see "Groups"
    And I should see "New Group"

  Scenario: Viewing groups page as a verified user
    Given I am signed in as "verified@example.com"
    When I visit the groups page
    Then I should see "Groups"
    And I should see "New Group"

  Scenario: Creating a public group as a verified user
    Given I am signed in as "verified@example.com"
    When I visit the groups page
    And I click "New Group"
    Then I should see "Create a New Group"
    When I fill in the following:
      | Group Name  | Tech Enthusiasts           |
      | Description | A group for tech lovers    |
      | Location    | San Francisco, CA          |
    And I check "Public group (visible to everyone)"
    And I click "Create Group"
    Then I should see "Group created successfully"
    And I should see "Tech Enthusiasts"
    And I should see "A group for tech lovers"

  Scenario: Creating a private group as an admin
    Given I am signed in as "admin@example.com"
    When I visit the groups page
    And I click "New Group"
    When I fill in the following:
      | Group Name  | Secret Society |
      | Description | Private group  |
    And I uncheck "Public group (visible to everyone)"
    And I click "Create Group"
    Then I should see "Group created successfully"
    And I should see "Secret Society"
    And I should see "Private"

  Scenario: Regular users can create groups
    Given I am signed in as "regular@example.com"
    When I visit "/groups/new"
    Then I should see "New Group"
    And I should see "Create a New Group"

  Scenario: Viewing a public group as a visitor
    Given a public group "Book Club" exists with owner "verified@example.com"
    When I visit the groups page
    Then I should see "Book Club"
    When I click on the group "Book Club"
    Then I should see "Book Club"

  Scenario: Cannot view private group as non-member
    Given a private group "VIP Club" exists with owner "admin@example.com"
    And I am signed in as "regular@example.com"
    When I visit the group page for "VIP Club"
    Then I should be redirected to "/groups"
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

  Scenario: Non-owner cannot edit group
    Given a public group "Book Club" exists with owner "verified@example.com"
    And I am signed in as "regular@example.com"
    When I visit the edit page for "Book Club"
    Then I should see "You don't have permission to edit this group"

  Scenario: Group name is required
    Given I am signed in as "verified@example.com"
    When I visit the groups page
    And I click "New Group"
    And I click "Create Group"
    Then I should see an error on the "Group Name" field
