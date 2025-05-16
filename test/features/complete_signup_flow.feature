Feature: Complete Signup Flow
  
  Scenario: User completes the entire signup flow including clicking the magic link
    Given the user is on the home page
    When the user clicks the "Sign Up" link in the navbar
    And the user enters an unregistered email address
    And the user submits the sign up form
    Then the user receives a confirmation message
    And the user receives a magic link email
    When the user clicks the magic link in the email
    Then the user is successfully signed in
    And the user can see their personal dashboard
