@conn
Feature: View In-Progress Huddlz
  As a user
  I want to see huddlz that are currently in progress
  So that I can join events that are happening right now

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | user@example.com | Test User    | regular |
    And there are huddlz in different states:
      | title                    | state        |
      | Future Workshop          | future       |
      | Currently Happening      | in_progress  |
      | Just Ended              | past         |

  Scenario: In-progress huddlz appear in upcoming events
    When I visit the home page
    Then I should see "Currently Happening" in the upcoming section
    And I should see "Future Workshop" in the upcoming section
    And I should not see "Just Ended" in the upcoming section

  Scenario: Past events are not shown on the home page
    When I visit the home page
    Then I should not see "Just Ended" in the upcoming section