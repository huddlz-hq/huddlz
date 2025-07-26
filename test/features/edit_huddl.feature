@conn
Feature: Edit Huddl
  As a group owner or organizer
  I want to edit huddlz for my groups
  So that members know when and where to meet

  Background:
    Given the following users exist:
      | email                 | role     | display_name |
      | owner@example.com     | verified | Group Owner  |
      | non_owner@example.com | verified | Other User   |
    Given the following huddlz exist:
      | name            | creator_name | group_name
      | Future Workshop | Group Owner  | Tech Meetup

  Scenario: Owner edits an in-person huddl
    Given I am signed in as "owner@example.com"
    When I visit the "Future Workshop" huddl page
    Then I should see "Edit Huddl"
    When I click "Edit Huddl"
    Then I should be on the edit huddl page for "Future Workshop"
    When I fill in the huddl form with:
      | Field             | Value                        |
      | Title             | Monthly Tech Workshop        |
      | Description       | Discussion about new tech    |
      | Start Date & Time | tomorrow at 6:00 PM          |
      | End Date & Time   | tomorrow at 8:00 PM          |
      | Event Type        | In-Person                    |
      | Physical Location | 123 Main St, Tech City       |
    And I save the form
    Then I should be redirected to the "Monthly Tech Workshop" huddl page
    And I should see "Huddl updated successfully!"

  Scenario: Non-owner cannot edit a huddl
    Given I am signed in as "non_owner@example.com"
    When I visit the "Future Workshop" huddl page
    Then I should not see "Edit Huddl"
    When I try to visit the "Future Workshop" edit huddl page
    Then I should be redirected to the "Future Workshop" huddl page
    And I should see "You don't have permission to edit this huddl"
