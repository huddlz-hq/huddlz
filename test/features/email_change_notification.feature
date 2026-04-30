@async @database
Feature: Email change notification email
  As a user
  I want both my old and new email addresses to receive a security notice
  When my account email changes
  So that an unauthorized change cannot go unnoticed

  Scenario: Two security notices are sent when a user changes their email
    Given the following users exist:
      | email           | display_name | role |
      | old@example.com | Eve          | user |
    And the user "old@example.com" has password "OldPassword123!"
    When "old@example.com" changes their email to "new@example.com" with password "OldPassword123!"
    Then a security notice should be sent to "old@example.com" naming the new address "new@example.com"
    And a confirmation should be sent to "new@example.com" naming the previous address "old@example.com"

  Scenario: No emails are sent if the email did not actually change
    Given the following users exist:
      | email           | display_name | role |
      | same@example.com | Stable      | user |
    And the user "same@example.com" has password "OldPassword123!"
    When "same@example.com" changes their email to "same@example.com" with password "OldPassword123!"
    Then no email-change notification should be sent
