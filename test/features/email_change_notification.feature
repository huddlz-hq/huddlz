@async @database
Feature: Email change approval email
  As a user
  I want both my old and new email addresses to receive an approval request
  When I request an account email change
  So that neither inbox alone can approve a change

  Scenario: Both inboxes receive approval requests
    Given the following users exist:
      | email           | display_name | role |
      | old@example.com | Eve          | user |
    And the user "old@example.com" has password "OldPassword123!"
    When "old@example.com" changes their email to "new@example.com" with password "OldPassword123!"
    Then an email-change approval should be sent to "old@example.com" naming the new address "new@example.com"
    And an email-change approval should be sent to "new@example.com" naming the previous address "old@example.com"

  Scenario: No emails are sent if the email did not actually change
    Given the following users exist:
      | email           | display_name | role |
      | same@example.com | Stable      | user |
    And the user "same@example.com" has password "OldPassword123!"
    When "same@example.com" changes their email to "same@example.com" with password "OldPassword123!"
    Then no email-change notification should be sent
