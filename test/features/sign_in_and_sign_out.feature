@async @database @conn
Feature: User Sign In and Sign Out

  Scenario: User signs in with password
    Given a user exists with email "test@example.com" and password "Password123!"
    And the user is on the home page
    When the user clicks the "Sign In" link in the navbar
    And the user enters "test@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user should be signed in
    And the user should see "huddlz"

  Scenario: User tries to sign in with wrong password
    Given a user exists with email "test@example.com" and password "Password123!"
    And the user is on the home page
    When the user clicks the "Sign In" link in the navbar
    And the user enters "test@example.com" in the email field
    And the user enters "WrongPassword" in the password field
    And the user submits the password sign in form
    Then the user should see "Incorrect email or password"
    And the user should not be signed in

  Scenario: User tries to sign in with an empty email field
    Given the user navigates to the sign in page
    When the user submits the password sign in form without entering an email address
    Then the user remains on the sign in page