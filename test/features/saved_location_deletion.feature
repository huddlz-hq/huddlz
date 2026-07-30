@async @database @conn
Feature: Safe saved-location deletion
  As a group organizer
  I want deliberate deletion safeguards for saved locations
  So scheduled huddlz do not lose their venue source unexpectedly

  Background:
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Group Owner  |
    And a public group "Book Club" exists with owner "owner@example.com"
    And the group "Book Club" has a saved location "Library" at "100 Main St" with coordinates 30.27, -97.74
    And I am signed in as "owner@example.com"

  Scenario: Deleting an unused saved location requires confirmation
    When I visit the locations page for "Book Club"
    And I click "Delete"
    Then I should see "Delete this saved location?"
    And I should see "It will no longer appear in future venue pickers"
    When I click "Keep location"
    Then I should see "Library"
    When I click "Delete"
    And I click "Delete location"
    Then I should see "Location deleted"
    And I should not see "Library"

  Scenario: A scheduled huddl blocks saved-location deletion
    Given the saved location "Library" is used by an upcoming huddl
    When I visit the locations page for "Book Club"
    And I click "Delete"
    Then I should see "This location is used by 1 current or upcoming huddl"
    And I should see "Move it to another venue before deleting it"
