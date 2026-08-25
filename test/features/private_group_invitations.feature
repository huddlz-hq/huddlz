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
    When I try to visit the group page for "Quiet Makers"
    Then I should see the branded not found recovery page
    When I visit "/notifications"
    Then I should see "Inbox · 1 unread"
    And I should see "Invites · 1"
    When I click "Mark all as read"
    Then I should see "Inbox · 0 unread"
    And I should see "Invites · 1"
    When I visit "/notifications?filter=invites"
    Then I should see "Invitation to Quiet Makers"
    When I click "Open"
    Then I should see "Back to invitations"
    When I click "Accept invitation"
    Then I should see "Welcome to Quiet Makers."
    And I should see "You accepted this invitation."
    When I click "Back to invitations"
    Then I should see "Invites · 0"
    And I should see "No pending invitations."
    When I visit "/my-groups"
    Then I should see "Quiet Makers"
