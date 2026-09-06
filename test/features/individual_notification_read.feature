@async @database @conn
Feature: Individual notification read state
  As a huddlz user
  I want to mark one linked notification read without leaving the page
  So that I can clear its unread state and still understand what happened

  Scenario: A read waitlist promotion remains visible in the Inbox
    Given I am signed in as "reader@example.com" with password "Password123!"
    And I have an unread waitlist promotion notification for "Elixir Picnic"
    When I visit "/notifications"
    Then I should see "Inbox · 1 unread"
    And persistent navigation should show one unread notification
    When I click the "Mark read" button
    Then I should see "Inbox · 0 unread"
    And persistent navigation should show no unread notifications
    And I should see "Waitlist promoted: Elixir Picnic"
    And I should see "Open"
    And the "Mark read" button should not be visible
    When I visit "/notifications?filter=invites"
    Then I should see "Invites · 0"
    And I should see "No pending invitations."
    And I should not see "Waitlist promoted: Elixir Picnic"
