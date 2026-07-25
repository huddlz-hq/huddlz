@async @database @conn
Feature: Cancel Huddl
  As a group owner or organizer
  I want to cancel published huddlz for my groups
  So that attendees are informed without losing history

  Background:
    Given the following users exist:
      | email                 | role     | display_name |
      | owner@example.com     | verified | Group Owner  |
      | non_owner@example.com | verified | Other User   |
    Given the following huddlz exist:
      | name            | creator_name | group_name
      | Future Workshop | Group Owner  | Tech Meetup

  Scenario: Owner cancels an in-person huddl
    Given I am signed in as "owner@example.com"
    When I visit the "Future Workshop" huddl page
    Then I should see "Cancel huddl"
    When I click "Cancel huddl"
    Then I should see "Cancel this huddl?"
    When I confirm cancelling the huddl
    Then I should see "This huddl was cancelled"
    And I should see "Huddl cancelled. Attendees have been notified."

  Scenario: Non-owner cannot cancel a huddl
    Given I am signed in as "non_owner@example.com"
    When I visit the "Future Workshop" huddl page
    Then I should not see "Cancel huddl"
