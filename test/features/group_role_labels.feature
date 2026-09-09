@async @database @conn @group_roles
Feature: Actual group role labels
  Role labels describe membership independently of administrative access.

  Background:
    Given the following users exist:
      | email                  | role  | display_name    |
      | owner315@example.com   | user  | Owner Olive     |
      | helper315@example.com  | user  | Organizer Oscar |
      | member315@example.com  | user  | Member Maya     |
      | admin315@example.com   | admin | Admin Alex      |
      | visitor315@example.com | user  | Visitor Vera    |
    And a public group "Role Labels" exists with owner "owner315@example.com"
    And "helper315@example.com" is an organizer of "Role Labels"
    And "member315@example.com" is a member of "Role Labels"

  Scenario: An organizer sees their actual role across group surfaces
    Given I am signed in as "helper315@example.com"
    When I visit the group page for "Role Labels"
    Then my group role should be "Organizer"
    And my navigation role for "Role Labels" should be "Organizer"
    When I visit "/groups"
    Then my card role for "Role Labels" should be "Organizer"

  Scenario: A mounted Groups card follows promotion and demotion
    Given I am signed in as "member315@example.com"
    When I visit "/groups"
    Then my card role for "Role Labels" should be "Member"
    When the owner promotes me in "Role Labels" in another session
    Then my card role for "Role Labels" should be "Organizer"
    And my navigation role for "Role Labels" should be "Organizer"
    When the owner demotes me in "Role Labels" in another session
    Then my card role for "Role Labels" should be "Member"

  Scenario Outline: Membership labels match the persisted role
    Given I am signed in as "<email>"
    When I visit the group page for "Role Labels"
    Then my group role should be "<role>"
    When I visit "/groups"
    Then my card role for "Role Labels" should be "<role>"

    Examples:
      | email                 | role   |
      | owner315@example.com  | Owner  |
      | member315@example.com | Member |

  Scenario Outline: Access without membership does not imply a group role
    Given I am signed in as "<email>"
    When I visit the group page for "Role Labels"
    Then I should have no group role label
    When I click the "Join Group" button
    Then my group role should be "Member"
    When I click the "Leave Group" button
    And I click the "Yes, leave group" button
    Then I should have no group role label
    When I click the "Join Group" button
    Then my group role should be "Member"

    Examples:
      | email                  |
      | admin315@example.com   |
      | visitor315@example.com |

  Scenario: Ownership transfer updates the former owner's mounted role
    Given I am signed in as "owner315@example.com"
    When I visit the group page for "Role Labels"
    Then my group role should be "Owner"
    When the owner transfers "Role Labels" to "helper315@example.com" in another session
    Then my group role should be "Organizer"
    And my navigation role for "Role Labels" should be "Organizer"
    When I open the organizer roster for "Role Labels"
    Then the group edit action should be hidden
    When I visit the edit page for "Role Labels"
    Then I should see "You don't have permission to edit this group"

  Scenario: Accepting an invitation adds a mounted Groups card
    Given a private group "Invitation Roles" exists with owner "owner315@example.com"
    And "visitor315@example.com" has an organizer invitation to "Invitation Roles"
    And I am signed in as "visitor315@example.com"
    When I visit "/groups"
    Then I should not see "Invitation Roles"
    When I accept my invitation to "Invitation Roles" in another session
    Then my card role for "Invitation Roles" should be "Organizer"
    And my navigation role for "Invitation Roles" should be "Organizer"

  Scenario: An invitation promotion updates a mounted group page
    Given a private group "Invitation Roles" exists with owner "owner315@example.com"
    And "member315@example.com" has an organizer invitation to "Invitation Roles"
    And "member315@example.com" is a member of "Invitation Roles"
    And I am signed in as "member315@example.com"
    When I visit the group page for "Invitation Roles"
    Then my group role should be "Member"
    When I accept my invitation to "Invitation Roles" in another session
    Then my group role should be "Organizer"
    And my navigation role for "Invitation Roles" should be "Organizer"
