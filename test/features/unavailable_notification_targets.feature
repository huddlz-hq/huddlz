@async @database @conn
Feature: Unavailable notification targets
  As a person reviewing past notifications
  I want unavailable destinations to be shown safely
  So that I keep the historical context without following a broken link

  Scenario: A deleted huddl remains visible without an Open action
    Given the following users exist:
      | email              | display_name | role |
      | member@example.com | Test Member  | user |
    And I am signed in as "member@example.com"
    And I have a notification for a deleted huddl named "Boat Drinks"
    When I visit "/notifications"
    Then I should see "Boat Drinks"
    And I should see "Destination unavailable"
    And I should not see "Open"
    And the "Mark read" button should be visible
