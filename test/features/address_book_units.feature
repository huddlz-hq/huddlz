@address_book_units @async @database @conn
Feature: Address book unit details
  As a group organizer
  I want to add a unit identifier to an address
  So people can find the right place inside a building

  Background:
    Given the following users exist:
      | email                           | role     | display_name |
      | owner+address-units@example.com | verified | Group Owner  |
    And a public group "Beach Neighbors" exists with owner "owner+address-units@example.com"
    And I am signed in as "owner+address-units@example.com"

  Scenario: Saving a unit with a street address
    When I visit the locations page for "Beach Neighbors"
    And I click "Add Address"
    And I choose the address book street address "320 1st St N, Jacksonville Beach, FL"
    And I fill in "Unit (optional)" with "4B"
    And I click "Save Address"
    And I visit the locations page for "Beach Neighbors"
    Then I should see "320 1st St N, Jacksonville Beach, FL Unit 4B"

    When I visit the new huddl page for "Beach Neighbors"
    And I fill in the huddl form with:
      | Field             | Value               |
      | Title             | Beach Room Meetup   |
      | Description       | Meet the neighbors  |
      | Date              | 2030-07-15          |
      | Start Time        | 19:00               |
      | Duration          | 1 hour              |
      | Huddl Type        | In-Person           |
      | Physical Location | Beach meeting place |
    And I submit the form
    And I visit the "Beach Room Meetup" huddl page
    Then I should see "320 1st St N, Jacksonville Beach, FL Unit 4B"

  Scenario: Adding and clearing unit details on an existing address
    Given the group "Beach Neighbors" has a saved location "Beach meeting place" at "320 1st St N, Jacksonville Beach, FL" with coordinates 30.292, -81.39
    When I visit the locations page for "Beach Neighbors"
    And I click "Edit"
    And I fill in "Unit (optional)" with "4B"
    And I click "Save"
    And I visit the locations page for "Beach Neighbors"
    Then I should see "320 1st St N, Jacksonville Beach, FL Unit 4B"
    When I click "Edit"
    And I fill in "Unit (optional)" with ""
    And I click "Save"
    And I visit the locations page for "Beach Neighbors"
    Then I should see "320 1st St N, Jacksonville Beach, FL"
    And I should not see "Unit 4B"

  Scenario: Saving an address without unit details
    When I visit the locations page for "Beach Neighbors"
    And I click "Add Address"
    And I choose the address book street address "320 1st St N, Jacksonville Beach, FL"
    And I click "Save Address"
    And I visit the locations page for "Beach Neighbors"
    Then I should see "320 1st St N, Jacksonville Beach, FL"
    And I should not see "Unit 4B"
