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
    And I click "Register"
    Then I should be signed in
    And I should see "Find your huddl"

  Scenario: User signs in with password
    Given a user exists with email "existing@example.com" and password "Password123!"
    And I am on the sign-in page
    When I fill in the password sign-in form with:
      | email    | existing@example.com |
      | password | Password123!         |
    And I click "Sign in"
    Then I should be signed in
    And I should see "Find your huddl"

  Scenario: User fails to sign in with wrong password
    Given a user exists with email "existing@example.com" and password "Password123!"
    And I am on the sign-in page
    When I fill in the password sign-in form with:
      | email    | existing@example.com |
      | password | WrongPassword        |
    And I click "Sign in"
    Then I should see "Email or password was incorrect"
    And I should not be signed in

  Scenario: User sets password in profile
    Given I am signed in as "magicuser@example.com" without a password
    When I go to my profile page
    And I click "Set Password"
    And I fill in the password form with:
      | password              | NewPassword123! |
      | password_confirmation | NewPassword123! |
    And I click "Set Password" 
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
    When I click "Forgot your password?"
    And I fill in "Email" with "forgetful@example.com"
    And I click "Request reset password link"
    Then I should see "If an account exists for forgetful@example.com, you will receive a password reset link shortly."

  Scenario: User can switch between authentication methods
    Given I am on the sign-in page
    Then I should see the password sign-in form
    And I should see the magic link form
    When I am on the registration page
    Then I should see the password registration form
    And I should see the magic link registration form