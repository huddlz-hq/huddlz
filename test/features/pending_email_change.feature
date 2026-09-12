@async @database @conn @dual_email_change
Feature: Both inboxes approve an email change
  Background:
    Given the following users exist:
      | email                     | display_name | role |
      | original+dual@example.com | Dual         | user |
    And the user "original+dual@example.com" has password "OldPassword123!"
    And I am signed in as "original+dual@example.com"
    And I visit "/profile"
    When I fill in "New email" with "replacement+dual@example.com"
    And I fill in "Confirm current password" with "OldPassword123!"
    And I click the "Change email" button

  Scenario: The original address stays active until both inboxes approve
    When I approve the email change from "original+dual@example.com"
    Then I should see "Approval recorded. The other inbox still needs to approve."
    When I visit "/profile"
    Then I should see "Awaiting approval from replacement+dual@example.com"
    And I should see "Your current sign-in address remains original+dual@example.com"
    When I approve the email change from "replacement+dual@example.com"
    Then I should see "Your email address has been changed"
    When I visit "/profile"
    Then I should see "replacement+dual@example.com"
    And I should not see "Pending email change"

  Scenario: Cancelling a pending change makes its approval links unusable
    When I click the "Cancel email change" button
    Then I should see "Email change cancelled"
    And I should not see "Remove"
    And I should not see "Pending email change"
    When I open the email-change link sent to "original+dual@example.com"
    Then I should see "This approval link is invalid, expired, or already used."

  Scenario: Resending is limited and keeps earlier approval links usable
    When I click the "Resend approval emails" button
    Then I should see "Approval emails sent. Check your inboxes and junk folders."
    When I click the "Resend approval emails" button
    Then I should see "Wait a minute between resends; at most five are allowed per hour."
    When I approve the email change from "replacement+dual@example.com"
    Then I should see "Approval recorded. The other inbox still needs to approve."
    When I approve the email change from "original+dual@example.com"
    Then I should see "Your email address has been changed"

  Scenario: An inbox owner can report an unexpected request without signing in
    When I open the email-change link sent to "replacement+dual@example.com" in a signed-out browser
    And I click the "Report and cancel this request" button
    Then I should see "Request reported and cancelled. No email address was changed."
    And I should see "If you own this huddlz account, reset your password to secure it."
    When I open the email-change link sent to "original+dual@example.com"
    Then I should see "This approval link is invalid, expired, or already used."
