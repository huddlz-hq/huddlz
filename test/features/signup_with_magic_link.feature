Feature: Signup with Magic Link

  Scenario: User signs up with a new account
    Given the user is on the home page
    When the user clicks the "Sign Up" link in the navbar
    And the user enters an unregistered email address
    And the user enters a display name
    And the user submits the sign up form
    Then the user receives a confirmation message
    And the user receives a magic link email

  Scenario: User signs up with a generated display name
    Given the user is on the home page
    When the user clicks the "Sign Up" link in the navbar
    And the user enters an unregistered email address
    And the user submits the sign up form with the generated display name
    Then the user receives a confirmation message
    And the user receives a magic link email

  Scenario: User tries to sign up with an invalid email format
    Given the user navigates to the sign up page
    When the user enters an invalid email address without an "@" character
    And the user submits the sign up form
    Then a validation error is shown indicating the email must be valid