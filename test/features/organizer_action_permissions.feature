@async @database @conn @organizer_permissions
Feature: Organizer action permissions
  The organizer workspace offers actions permitted for the current person.

  Background:
    Given the following users exist:
      | email                 | role | display_name    |
      | owner314@example.com  | user | Owner Olive     |
      | helper314@example.com | user | Organizer Oscar |
      | admin314@example.com  | admin | Admin Alex     |
      | member314@example.com | user | Member Maya    |
    And a public group "Organizer Permissions" exists with owner "owner314@example.com"
    And "helper314@example.com" is an organizer of "Organizer Permissions"

  Scenario: An organizer is not offered owner-only group editing
    Given I am signed in as "helper314@example.com"
    When I open the organizer roster for "Organizer Permissions"
    Then the group edit action should be hidden

  Scenario Outline: Authorized people can open the group editor
    Given I am signed in as "<email>"
    When I open the organizer roster for "Organizer Permissions"
    And I click link "Edit group"
    Then I should see "Edit Group"
    And the "Save Changes" button should be visible

    Examples:
      | email                |
      | owner314@example.com |
      | admin314@example.com |

  Scenario: A member cannot open the workspace directly
    Given "member314@example.com" is a member of "Organizer Permissions"
    And I am signed in as "member314@example.com"
    When I open the organizer roster for "Organizer Permissions"
    Then I should see "That group doesn't exist, or you don't organize it."
    And the group edit action should be hidden

  Scenario: A signed-out visitor must sign in to open the workspace
    When I open the organizer roster for "Organizer Permissions"
    Then the "Sign in" button should be visible

  Scenario: Demotion removes a mounted organizer workspace
    Given I am signed in as "helper314@example.com"
    When I open the organizer roster for "Organizer Permissions"
    And the owner demotes me in "Organizer Permissions" in another session
    Then the organizer roster should be inaccessible

  Scenario: Leaving in another session removes a mounted organizer workspace
    Given I am signed in as "helper314@example.com"
    When I open the organizer roster for "Organizer Permissions"
    And I leave "Organizer Permissions" in another session
    Then the organizer roster should be inaccessible

  Scenario: An organizer cannot revoke an owner-issued organizer invitation
    Given a private group "Private Permissions" exists with owner "owner314@example.com"
    And "helper314@example.com" is an organizer of "Private Permissions"
    And "member314@example.com" has an organizer invitation to "Private Permissions"
    And I am signed in as "helper314@example.com"
    When I open the organizer roster for "Private Permissions"
    Then I should see "Awaiting response"
    And the "Revoke" button should not be visible

  Scenario: Ownership loss closes an unauthorized pending confirmation
    Given "member314@example.com" is a member of "Organizer Permissions"
    And I am signed in as "owner314@example.com"
    When I open the organizer roster for "Organizer Permissions"
    And I open the promotion confirmation for "Member Maya"
    And I transfer "Organizer Permissions" to "helper314@example.com" in another session
    Then the membership action confirmation should be closed
    And the group edit action should be hidden
