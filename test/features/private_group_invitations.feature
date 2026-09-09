@database @conn @launch_invitations
Feature: Private group invitations
  Organizers can invite people by email without exposing private groups.

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
    Then I should see "Inbox 1 unread"
    And I should see "Invites 1"
    When I click "Mark all as read"
    Then I should see "Inbox 0 unread"
    And I should see "Invites 1"
    When I visit "/notifications?filter=invites"
    Then I should see "Invitation to Quiet Makers"
    When I click "Open"
    Then I should see "Back to invitations"
    When I click "Accept invitation"
    Then I should see "Welcome to Quiet Makers."
    And I should see "You accepted this invitation."
    When I click "Back to invitations"
    Then I should see "Invites 0"
    And I should see "No pending invitations"
    When I visit "/groups"
    Then I should see "Quiet Makers"

  Scenario: A new recipient registers from their email and accepts the intended invitation
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    Then I should see "Invitation sent to new-maker@example.com."
    And an invitation email should be sent to "new-maker@example.com" for "Quiet Makers"
    When I follow that invitation email while signed out
    Then I should see "Sign in"
    When I click "Sign up"
    And I complete registration as "new-maker@example.com"
    Then I should see "Group invitation"
    And I should see "Quiet Makers"
    And I should see "Accept invitation"
    When I try to visit the group page for "Quiet Makers"
    Then I should see the branded not found recovery page
    When I reopen the invitation email
    And I click "Accept invitation"
    Then I should see "Welcome to Quiet Makers."
    When I click "Open group"
    Then I should see "Quiet Makers"

  Scenario: An invitation email does not give a different account private group access
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    Then an invitation email should be sent to "new-maker@example.com" for "Quiet Makers"
    When I follow that invitation email while signed out
    And I click "Sign up"
    And I complete registration as "different-maker@example.com"
    Then I should see "Sign in with the email address that received it"
    And I should not see "Accept invitation"
    When I try to visit the group page for "Quiet Makers"
    Then I should see the branded not found recovery page

  Scenario: An organizer cannot send a duplicate pending email invitation
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    Then I should see "Invitation sent to new-maker@example.com."
    When I submit a member invitation for "NEW-MAKER@example.com"
    Then I should see "Could not send that invitation."
    And I should see "Awaiting response"

  Scenario: A revoked email invitation cannot be claimed after registration
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    Then an invitation email should be sent to "new-maker@example.com" for "Quiet Makers"
    When I click "Revoke"
    Then I should see "Revoked"
    When I follow that invitation email while signed out
    And I click "Sign up"
    And I complete registration as "new-maker@example.com"
    Then I should see "That invitation isn't available."
    And I should not see "Accept invitation"
    When I try to visit the group page for "Quiet Makers"
    Then I should see the branded not found recovery page

  Scenario: A new recipient can decline without joining and revisit without duplicate notifications
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    Then an invitation email should be sent to "new-maker@example.com" for "Quiet Makers"
    When I follow that invitation email while signed out
    And I click "Sign up"
    And I complete registration as "new-maker@example.com"
    And I click "Decline"
    Then I should see "Invitation declined."
    When I reopen the invitation email
    Then I should see "You declined this invitation."
    When I visit "/notifications"
    Then I should see "Inbox 1 unread"
    And I should see "Invites 0"
    When I try to visit the group page for "Quiet Makers"
    Then I should see the branded not found recovery page

  Scenario: Expired invitations remain unavailable and can be replaced
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    Then an invitation email should be sent to "new-maker@example.com" for "Quiet Makers"
    Given the pending invitation to "new-maker@example.com" for "Quiet Makers" has expired
    When I open the member workspace for "Quiet Makers"
    Then I should see "Expired"
    When I submit a member invitation for "new-maker@example.com"
    Then I should see "Invitation sent to new-maker@example.com."
    And I should see "Awaiting response"
    When I follow that invitation email while signed out
    And I click "Sign up"
    And I complete registration as "new-maker@example.com"
    Then I should see "That invitation isn't available."
    And I should not see "Accept invitation"

  Scenario: Sharing a private group link does not grant access
    Given I am signed in as "owner@example.com"
    When I visit the group page for "Quiet Makers"
    Then "Quiet Makers" has working email and QR sharing controls
    When I open that shared group link while signed out
    Then I should see the branded not found recovery page
    Given I am signed in as "invitee@example.com"
    When I try to visit the group page for "Quiet Makers"
    Then I should see the branded not found recovery page

  Scenario: Registered recipients keep their invitation email preference
    Given I am signed in as "invitee@example.com"
    When I visit "/profile/notifications"
    And I uncheck "I was invited to a group"
    And I click "Save preferences"
    Then I should see "Notification preferences saved"
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "invitee@example.com"
    Then no invitation email should be sent to "invitee@example.com"
    Given I am signed in as "invitee@example.com"
    When I visit "/notifications?filter=invites"
    Then I should see "Invitation to Quiet Makers"
    When I click "Open"
    And I click "Accept invitation"
    Then I should see "Welcome to Quiet Makers."

  Scenario: Queued invitations respect preferences chosen after independent registration
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    And I start registration without an invitation link
    And I complete registration as "new-maker@example.com"
    And I visit "/profile/notifications"
    And I uncheck "I was invited to a group"
    And I click "Save preferences"
    Then I should see "Notification preferences saved"
    And no invitation email should be sent to "new-maker@example.com"

    When I confirm the registration email sent to "new-maker@example.com"
    And I visit "/notifications?filter=invites"
    Then I should see "Invitation to Quiet Makers"
    When I click "Open"
    And I click "Accept invitation"
    Then I should see "Welcome to Quiet Makers."
    And no invitation email should be sent to "new-maker@example.com"

  Scenario: Independently registered recipients confirm their email before invitation delivery
    Given I am signed in as "owner@example.com"
    When I open the member workspace for "Quiet Makers"
    And I submit a member invitation for "new-maker@example.com"
    And I start registration without an invitation link
    And I complete registration as "new-maker@example.com"
    Then no invitation email should be sent to "new-maker@example.com"
    When I visit "/notifications?filter=invites"
    Then I should see "No pending invitations"
    When I confirm the registration email sent to "new-maker@example.com"
    Then an invitation email should be sent to "new-maker@example.com" for "Quiet Makers"
    And that invitation email includes notification preferences and unsubscribe links
    When I visit "/notifications?filter=invites"
    Then I should see "Invitation to Quiet Makers"
