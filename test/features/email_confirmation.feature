@database @conn @email_confirmation
Feature: Email confirmation status
  As a person whose address is not confirmed yet
  I want to see that, and get another confirmation email when the first went astray
  So that my reminders and group updates reach me

  Background:
    Given the following users exist:
      | email                | role | display_name |
      | maya573@example.com  | user | Member Maya  |
      | olive573@example.com | user | Owner Olive  |
    And "maya573@example.com" has not confirmed their address

  Scenario: Confirming spends the remaining links
    Given I am signed in as "maya573@example.com"
    And I have two unexpired confirmation links
    When I follow one of them
    And I open the other
    Then I am told the link no longer works
    And "maya573@example.com" is confirmed now

  Scenario: A link older than three days no longer works
    Given I am signed in as "maya573@example.com"
    And my confirmation link was sent four days ago
    When I open it
    Then I am told the link no longer works

  Scenario: A link for a previous address cannot confirm or restore it
    Given "maya573@example.com" has an unexpired confirmation link
    And that account's address has since changed to "maya@work.example"
    When the old link is opened
    Then I am told the link was for a previous address
    And the account's address is still "maya@work.example" and not confirmed

  Scenario: Resend is an account action reachable through the API
    Given resend limits are enforced
    When "maya573@example.com" asks for the confirmation email through GraphQL
    Then a confirmation email is sent to "maya573@example.com"
    When "maya573@example.com" asks for the confirmation email through GraphQL
    Then the API refuses the resend with a retry time
