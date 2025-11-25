@async @database @conn
Feature: Delete Huddl
  As a group owner or organizer
  I want to delete huddlz for my groups
  So that huddlz that are no longer occurring are removed

  Background:
    Given the following users exist:
      | email                 | role     | display_name |
      | owner@example.com     | verified | Group Owner  |
      | non_owner@example.com | verified | Other User   |
    Given the following huddlz exist:
      | name            | creator_name | group_name
      | Future Workshop | Group Owner  | Tech Meetup

  Scenario: Owner deletes an in-person huddl
    Given I am signed in as "owner@example.com"
    When I visit the "Future Workshop" huddl page
    Then I should see "Delete Huddl"
    When I click "Delete Huddl"
    Then I should be redirected to the "Tech Meetup" group page
    And I should see "Huddl deleted successfully!"

  Scenario: Non-owner cannot delete a huddl
    Given I am signed in as "non_owner@example.com"
    When I visit the "Future Workshop" huddl page
    Then I should not see "Delete Huddl"
