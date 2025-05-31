@conn
Feature: User Sign In and Sign Out

  Scenario: User requests a magic link for an existing account
    Given the user is on the home page
    When the user clicks the "Sign In" link in the navbar
    And the user enters a registered email address for magic link authentication
    And the user submits the sign in form
    Then the user receives a confirmation message
    And the user receives a magic link email

  Scenario: User submits the sign in form with an email address
    Given the user is on the home page
    When the user clicks the "Sign In" link in the navbar
    And the user enters an email address for magic link authentication
    And the user submits the sign in form
    Then the user sees a message indicating that a magic link was sent if the account exists

  Scenario: User tries to sign in with an empty email field
    Given the user navigates to the sign in page
    When the user submits the sign in form without entering an email address
    Then the user remains on the sign in page
