@conn
Feature: Password Authentication
  As a user
  I want to be able to sign up and sign in with a password
  So that I can access the platform without relying on email links

  Scenario: User registers with password
    Given I am on the registration page
    When I fill in the password registration form with:
      | email                    | newuser@example.com    |
      | password                 | SuperSecret123!        |
      | password_confirmation    | SuperSecret123!        |
    And I click "Create account"
    Then I should be signed in
    And I should see "Find your huddl"

  Scenario: User signs in with password
    Given a user exists with email "existing@example.com" and password "Password123!"
    And I am on the sign-in page
    When I fill in the password sign-in form with:
      | email    | existing@example.com |
      | password | Password123!         |
    And I submit the password sign-in form
    Then I should be signed in
    And I should see "Find your huddl"

  Scenario: User fails to sign in with wrong password
    Given a user exists with email "existing@example.com" and password "Password123!"
    And I am on the sign-in page
    When I fill in the password sign-in form with:
      | email    | existing@example.com |
      | password | WrongPassword        |
    And I submit the password sign-in form
    Then I should see "Incorrect email or password"
    And I should not be signed in

  Scenario: User sets password in profile
    Given I am signed in as "magicuser@example.com" without a password
    When I go to my profile page
    And I click "Set Password"
    And I fill in the password form with:
      | password              | NewPassword123! |
      | password_confirmation | NewPassword123! |
    And I submit the password form
    Then I should see "Password updated successfully"

  Scenario: User changes existing password
    Given I am signed in as "pwduser@example.com" with password "OldPassword123!"
    When I go to my profile page
    And I click "Change Password"
    And I fill in the password form with:
      | current_password      | OldPassword123! |
      | password              | NewPassword123! |
      | password_confirmation | NewPassword123! |
    And I click "Update Password"
    Then I should see "Password updated successfully"

  Scenario: User requests password reset
    Given a user exists with email "forgetful@example.com" and password "ForgottenPassword123!"
    And I am on the sign-in page
    When I visit "/reset"
    And I fill in "Email" with "forgetful@example.com" within "#reset-password-form"
    And I click "Send reset instructions"
    Then I should see "If an account exists for that email, you will receive password reset instructions shortly."

  # This scenario is commented out because PhoenixTest/LiveViewTest doesn't properly
  # handle the phx-trigger-action JavaScript behavior needed for the LiveView to
  # controller form submission. The functionality is tested in:
  # test/huddlz_web/live/basic_password_reset_test.exs
  #
  # Scenario: User completes password reset via email link
  #   Given a confirmed user exists with email "reset@example.com" and password "OldPassword123!"
  #   When I visit "/reset"
  #   And I fill in "Email" with "reset@example.com" within "#reset-password-form"
  #   And I click "Send reset instructions"
  #   Then I should receive a password reset email for "reset@example.com"
  #   When I click the password reset link in the email
  #   Then I should be on the password reset confirmation page
  #   When I fill in the new password form with:
  #     | password              | NewSecurePassword123! |
  #     | password_confirmation | NewSecurePassword123! |
  #   And I click "Reset password"
  #   Then I should see "Your password has successfully been reset"
  #   And I should be signed in
  #   # Verify the password was actually changed by signing out and back in
  #   When I click "Sign Out"
  #   And I am on the sign-in page
  #   And I fill in the password sign-in form with:
  #     | email    | reset@example.com     |
  #     | password | NewSecurePassword123! |
  #   And I submit the password sign-in form
  #   Then I should be signed in

  Scenario: User can switch between authentication methods
    Given I am on the sign-in page
    Then I should see the password sign-in form
    And I should see the magic link form
    When I am on the registration page
    Then I should see the password registration form
