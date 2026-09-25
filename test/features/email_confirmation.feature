# Keep serial: scenarios change the global mailer adapter.
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

  Scenario: An unconfirmed person is told on every page
    Given I am signed in as "maya573@example.com"
    When I visit "/agenda"
    Then I am told to confirm my address "maya573@example.com"
    And I am offered to resend the confirmation

  Scenario: A confirmed person is not reminded
    Given I am signed in as "olive573@example.com"
    When I visit "/agenda"
    Then I am not told to confirm my address

  Scenario: Hiding the reminder lasts for the session
    Given the user "maya573@example.com" has password "Password123!"
    And I am signed in as "maya573@example.com"
    When I hide the confirmation reminder
    And I visit "/groups"
    Then I am not told to confirm my address
    When I sign out and sign in again as "maya573@example.com" with password "Password123!"
    Then I am told to confirm my address "maya573@example.com"

  Scenario: The profile keeps the status and controls after hiding
    Given I am signed in as "maya573@example.com"
    And I hide the confirmation reminder
    When I visit "/profile"
    Then my email is shown as "Not confirmed"
    And I am offered to resend the confirmation

  Scenario: Confirming removes the reminder
    Given I am signed in as "maya573@example.com"
    And I ask for the confirmation email again
    When I follow the confirmation link from the email
    And I visit "/profile"
    Then my email is shown as "Confirmed"
    And I am not told to confirm my address

  Scenario: Resending sends another confirmation to the current address
    Given I am signed in as "maya573@example.com"
    When I ask for the confirmation email again
    Then a confirmation email is sent to "maya573@example.com"
    And I am told it was sent and to look in junk

  Scenario: A second request within a minute is refused with a retry time
    Given resend limits are enforced
    And I am signed in as "maya573@example.com"
    And I asked for the confirmation email a moment ago
    When I ask for the confirmation email again
    Then no confirmation email is sent
    And I am told when I can try again

  Scenario: Five requests in an hour is the limit, even when they arrive together
    Given resend limits are enforced
    And "maya573@example.com" asked for the confirmation email five times this hour
    When "maya573@example.com" asks for the confirmation email through the API twice at once
    Then both requests are refused
    And no confirmation email is sent

  Scenario: A failed send says nothing went out
    Given I am signed in as "maya573@example.com"
    And email cannot be sent right now
    When I ask for the confirmation email again
    Then I am told nothing went out and to try again
    And "maya573@example.com" has no confirmation links

  Scenario: Resending keeps earlier links working
    Given I am signed in as "maya573@example.com"
    And I asked for the confirmation email an hour ago
    When I ask for the confirmation email again
    And I follow the earlier confirmation link
    And I visit "/profile"
    Then my email is shown as "Confirmed"

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

  Scenario: Retrying a failed send does not claim an email was sent
    Given resend limits are enforced
    And I am signed in as "maya573@example.com"
    And email cannot be sent right now
    When I ask for the confirmation email again
    Then I am told nothing went out and to try again
    When I ask for the confirmation email again
    Then I am told when I can try again
    And the retry guidance does not claim an email was sent
    When "maya573@example.com" asks for the confirmation email through GraphQL
    Then the API refuses the resend with a retry time
    And the API retry guidance does not claim an email was sent
    And no confirmation email is sent

  Scenario: An address changes while the confirmation page is open
    Given "maya573@example.com" has an unexpired confirmation link
    And the old link is opened
    And that account's address has since changed to "maya573@work.example"
    When I submit the open confirmation page
    Then the confirmation failure explains that the link was for a previous address
    And the account's address is still "maya573@work.example" and not confirmed
