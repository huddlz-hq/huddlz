@async @database @conn
Feature: Unsubscribe URL
  As a user
  I want a safe way to opt out of an email category from the email itself
  So that I do not have to sign in just to silence a single trigger

  Scenario: A signed-in user confirms a valid unsubscribe URL and the preference flips
    Given I am signed in as "unsub@example.com" with password "Password123!"
    When I visit the unsubscribe URL for trigger "rsvp_received"
    Then I should see "Confirm unsubscribe"
    And the user "unsub@example.com" should not have trigger "rsvp_received" disabled
    When I confirm the unsubscribe
    Then I should see "Unsubscribed from"
    And I should see "Choose which emails you want to receive"
    And the user "unsub@example.com" should have trigger "rsvp_received" disabled

  Scenario: An invalid unsubscribe token redirects with an error
    When I visit "/unsubscribe/not-a-token"
    Then I should see "This unsubscribe link is invalid or has expired."
