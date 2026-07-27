@async @database @conn
Feature: Individual notification read state
  As a huddlz user
  I want to mark one linked notification read without leaving the page
  So that I can clear its unread state and still understand what happened

  Scenario: A read waitlist promotion remains visible in Invites
    Given I am signed in as "reader@example.com" with password "Password123!"
    And I have an unread waitlist promotion notification for "Elixir Picnic"
    When I visit "/notifications?filter=invites"
    Then I should see "Inbox · 1 unread"
    When I click the "Mark read" button
    Then I should see "Inbox · 0 unread"
    And I should see "Waitlist promoted: Elixir Picnic"
    And I should see "Open"
    And the "Mark read" button should not be visible
