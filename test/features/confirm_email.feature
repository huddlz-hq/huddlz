@database @conn @confirm_email
Feature: Confirming an email address
  As someone who just registered
  I want the confirmation link to land on a huddlz page
  So that finishing my account feels like the rest of the app

  Scenario: The confirmation link lands on a huddlz page
    Given I start registration without an invitation link
    And I complete registration as "new@example.com"
    When I open the confirmation link sent to "new@example.com"
    Then I see a huddlz page asking me to confirm my email
    And I should not see "Ash Framework"

  Scenario: Confirming completes the account
    Given I start registration without an invitation link
    And I complete registration as "new@example.com"
    When I open the confirmation link sent to "new@example.com"
    And I click "Confirm my email"
    Then "new@example.com" is confirmed
    And I should see "Your email address has now been confirmed"

  Scenario: A used link explains itself
    Given I start registration without an invitation link
    And I complete registration as "new@example.com"
    And I open the confirmation link sent to "new@example.com"
    And I click "Confirm my email"
    When I open that confirmation link again
    Then the page tells me the link no longer works and offers to sign in

  Scenario: No auth page carries the library branding
    When I visit "/sign-in"
    Then I should not see "Ash Framework"
    When I visit "/register"
    Then I should not see "Ash Framework"
    When I visit "/reset"
    Then I should not see "Ash Framework"
    When I visit "/reset/not-a-real-token"
    Then I should not see "Ash Framework"
    When I visit "/confirm_new_user/not-a-real-token"
    Then I should not see "Ash Framework"
    And the page tells me the link no longer works and offers to sign in
