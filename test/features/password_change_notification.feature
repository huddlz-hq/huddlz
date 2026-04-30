@async @database @conn
Feature: Password change notification email
  As a user
  I want to receive a security email when my password changes
  So that I can take action if it was not me

  Scenario: A security notice is emailed after a successful password change
    Given I am signed in as "secure@example.com" with password "OldPassword123!"
    When I go to my profile page
    And I fill in the password form with:
      | current_password      | OldPassword123! |
      | password              | NewPassword456! |
      | password_confirmation | NewPassword456! |
    And I click "Update Password"
    Then I should see "Password updated successfully"
    And a password-changed notification should be sent to "secure@example.com"
