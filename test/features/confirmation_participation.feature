@async @database @conn @confirmation_participation
Feature: Confirming before participation
  A person proves their address before joining groups or RSVPing.
  Confirmation returns them to their destination without acting for them.

  Background:
    Given the following users exist:
      | email                 | role | display_name |
      | owner575@example.com  | user | Owner        |
      | member575@example.com | user | Member       |
    And the following group exists:
      | name           | description | is_public | owner_email          |
      | Makers 575     | Making      | true      | owner575@example.com |
    And the following huddl exists in "Makers 575":
      | title        | description | event_type | starts_at    | virtual_link           |
      | Making Night | Make things | virtual    | tomorrow 2pm | https://meet.example/a |
    And "member575@example.com" has not confirmed their address

  Scenario: An unconfirmed person cannot RSVP
    Given I am signed in as "member575@example.com"
    When I visit the "Making Night" huddl page
    Then I should see "Confirm your email before you RSVP"
    And I should not see "RSVP to this huddl"
    And I am offered to resend the confirmation

  Scenario: Old credentials cannot bypass confirmation
    When the unconfirmed member tries to RSVP using earlier credentials
    Then every RSVP request is refused and no spot is reserved

  Scenario: Registration and confirmation in another browser return to an explicit RSVP
    Given I start in a signed-out browser
    When I visit the "Making Night" huddl page
    And I click "Sign in to RSVP"
    And I click "Sign up"
    And I complete registration as "new575@example.com"
    Then I should be on the huddl page for "Making Night"
    And I should see "Confirm your email before you RSVP"
    When I confirm the email for "new575@example.com" in another browser
    Then I should be on the huddl page for "Making Night"
    And I should see "RSVP to this huddl"
    And I should not see "You're attending"
    When I click "RSVP to this huddl"
    Then I should see "You're attending"

  Scenario: Signing in and resending preserve a group destination
    Given the user "member575@example.com" has password "Password123!"
    And I start in a signed-out browser
    When I visit "/groups/makers-575"
    And I click "Sign in to join"
    And I fill in "Email" with "member575@example.com"
    And I fill in "Password" with "Password123!"
    And I click "Sign in"
    Then I should see "Confirm your email before you join"
    And I should not see "Join Group"
    When I click "Resend email"
    And I confirm the email for "member575@example.com" in another browser
    Then I should see "Makers 575"
    And I should see "Join Group"
    And I should not see "Leave Group"
    When I click "Join Group"
    Then I should see "Successfully joined the group!"

  Scenario: An invitation waits for confirmation in another browser and explicit acceptance
    Given a private group "Private Makers 575" exists with owner "owner575@example.com"
    And I am signed in as "owner575@example.com"
    When I open the member workspace for "Private Makers 575"
    And I submit a member invitation for "invited575@example.com"
    Then an invitation email should be sent to "invited575@example.com" for "Private Makers 575"
    When I follow that invitation email while signed out
    And I click "Sign up"
    And I complete registration as "invited575@example.com"
    Then I should see "Confirm your email before you accept an invitation"
    And I should not see "Accept invitation"
    When I confirm the email for "invited575@example.com" in another browser
    Then I should see "Private Makers 575"
    And I should see "Accept invitation"
    And I should not see "You accepted this invitation."
    When I click "Accept invitation"
    Then I should see "Welcome to Private Makers 575."

  Scenario: Existing owners must confirm before using their group roles
    Given "owner575@example.com" has not confirmed their address
    And I am signed in as "owner575@example.com"
    When I visit "/groups/makers-575"
    Then I should not see "Create Huddl"
    And I should not see "Edit Group"
    When I visit "/organize/makers-575"
    Then I should see "Confirm your email before organizing"
    And my email is shown as "Not confirmed"
    When the unconfirmed owner tries public participation actions
    Then those participation actions are forbidden

  Scenario: An already-open page checks the account again before RSVP
    Given "member575@example.com" is confirmed for this visit
    And I am signed in as "member575@example.com"
    And I visit the "Making Night" huddl page
    And "member575@example.com" has not confirmed their address
    When I click "RSVP to this huddl"
    Then I should see "Confirm your email before participating"
    And I should not see "You're attending"
    And I should see "Review confirmation and resend email"

  Scenario: Availability is checked after confirmation
    Given I am signed in as "member575@example.com"
    When I visit the "Making Night" huddl page
    And I click "Resend email"
    And "Making Night" fills while I check my email
    And I confirm the email for "member575@example.com" in another browser
    Then I should see "Join waitlist"
    And I should not see "You're attending"
    When I click "Join waitlist"
    Then I should see "On waitlist"

  Scenario: An invitation expires during confirmation
    Given a private group "Private Makers 575" exists with owner "owner575@example.com"
    And I am signed in as "owner575@example.com"
    When I open the member workspace for "Private Makers 575"
    And I submit a member invitation for "expired575@example.com"
    Then an invitation email should be sent to "expired575@example.com" for "Private Makers 575"
    When I follow that invitation email while signed out
    And I click "Sign up"
    And I complete registration as "expired575@example.com"
    And the pending invitation to "expired575@example.com" for "Private Makers 575" has expired
    And I confirm the email for "expired575@example.com" in another browser
    Then I should see "This invitation expired before it was accepted."
    And I should not see "Accept invitation"
    And I should not see "You accepted this invitation."

  Scenario: Unsafe destinations cannot redirect confirmation
    Given I am signed in as "member575@example.com"
    When unsafe confirmation destinations are submitted:
      | destination                                |
      | https://evil.example/groups/makers-575      |
      | //evil.example/groups/makers-575            |
      | /groups/../sign-out                         |
      | /groups/makers-575?return_to=//evil.example  |
      | /groups/%2f%2fevil.example                  |
      | /auth/user/password/sign_in_with_token      |
      | /groups/new                                |
    Then each unsafe confirmation destination is refused
    When I click "Resend email"
    And I confirm the email for "member575@example.com" in another browser
    Then confirmation lands on my normal agenda
