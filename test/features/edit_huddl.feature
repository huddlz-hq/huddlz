@async @database @conn
Feature: Edit Huddl Location
  As a group owner editing an existing huddl
  I want my chosen location's coordinates to persist
  So the huddl can be discovered by location-based search

  Background:
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Group Owner  |
    And a public group "Tech Meetup" exists with owner "owner@example.com"

  Scenario: Saving a huddl whose location matches a saved one persists those coordinates
    Given the group "Tech Meetup" has a saved location "Convention Center" at "500 E Cesar Chavez St" with coordinates 30.27, -97.74
    And the group "Tech Meetup" has a huddl "Existing" at "500 E Cesar Chavez St"
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Existing"
    Then the saved location "Convention Center" should be preselected
    When I click the "Save changes" button
    Then I should see "Huddl updated successfully"
    And the huddl "Existing" should have coordinates 30.27, -97.74

  Scenario: Switching to a different saved location persists the new coordinates
    Given the group "Tech Meetup" has a saved location "Original" at "Original Address, Austin, TX" with coordinates 30.27, -97.74
    And the group "Tech Meetup" has a saved location "Houston Hub" at "Houston Address, Houston, TX" with coordinates 29.76, -95.37
    And the group "Tech Meetup" has a huddl "Movable" at "Original Address, Austin, TX"
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Movable"
    And I switch the saved location to "Houston Hub"
    And I click the "Save changes" button
    Then I should see "Huddl updated successfully"
    And the huddl "Movable" should have coordinates 29.76, -95.37

  Scenario: Adding a brand-new address via the modal updates the huddl coordinates
    Given the group "Tech Meetup" has a huddl "Relocating" at "Old Address, Austin, TX"
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Relocating"
    And I add a new saved address "Saint Augustine, FL, USA" with coordinates 29.89, -81.31 via the modal
    And I click the "Save changes" button
    Then I should see "Huddl updated successfully"
    And the huddl "Relocating" should have coordinates 29.89, -81.31

  Scenario: Adding another address while a saved location is preselected persists the modal coordinates
    Given the group "Tech Meetup" has a saved location "Convention Center" at "500 E Cesar Chavez St" with coordinates 30.27, -97.74
    And the group "Tech Meetup" has a huddl "Movable Pre" at "500 E Cesar Chavez St"
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Movable Pre"
    Then the saved location "Convention Center" should be preselected
    When I add a new saved address "Saint Augustine, FL, USA" with coordinates 29.89, -81.31 via the modal
    And I click the "Save changes" button
    Then I should see "Huddl updated successfully"
    And the huddl "Movable Pre" should have coordinates 29.89, -81.31
