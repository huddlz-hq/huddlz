@database @conn
Feature: Private group invitations
  Organizers can invite registered people without exposing private groups.

  Background:
    Given the following users exist:
      | email                 | role | display_name |
      | owner@example.com     | user | Group Owner  |
      | invitee@example.com   | user | Invited User |
    And a private group "Quiet Makers" exists with owner "owner@example.com"

  Scenario: An invited person accepts and gains private group access
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "invitee@example.com"
    Then I should see "Invitation sent to invitee@example.com."
    And an invitation email should be sent to "invitee@example.com" for "Quiet Makers"
    Given I am signed in as "invitee@example.com"
    When I visit the group page for "Quiet Makers"
    Then I should see "Group not found"
    When I open my invitation to "Quiet Makers"
    And I click "Accept invitation"
    Then I should see "Welcome to Quiet Makers."
    When I visit "/my-groups"
    Then I should see "Quiet Makers"
