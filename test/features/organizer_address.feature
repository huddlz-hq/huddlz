@organizer_address @async @database @conn
Feature: Organizers write the address for an address book location
  As a group organizer
  I want to write the address people read, starting from the place I pick
  So they can find a venue, a room or a suite, while the map still opens the right place

  Background:
    Given the following users exist:
      | email                      | role     | display_name |
      | owner+address@example.com  | verified | Group Owner  |
    And a public group "Riverside Runners" exists with owner "owner+address@example.com"
    And I am signed in as "owner+address@example.com"

  Scenario: A venue's address starts with its name
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the venue "Starbucks Coffee Company" at "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    Then the address reads "Starbucks Coffee Company" then "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"

  Scenario: A street's address is its full address
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the street "Old Saint Augustine Road" at "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    Then the address reads "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"

  Scenario: The organizer edits the address
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the venue "Alfred's" at "222 W King St, St. Augustine, FL 32084, USA"
    And I fill in "Address" with "Back room, 222 West King Street, St. Augustine, FL"
    And I click "Save Address"
    And I visit the locations page for "Riverside Runners"
    Then I should see "Back room, 222 West King Street, St. Augustine, FL"

    When I visit the new huddl page for "Riverside Runners"
    And I fill in the huddl form with:
      | Field             | Value              |
      | Title             | Back Room Social   |
      | Description       | Meet in the back   |
      | Date              | 2030-07-15         |
      | Start Time        | 19:00              |
      | Duration          | 1 hour             |
      | Huddl Type        | In-Person          |
      | Physical Location | Alfred's           |
    And I submit the form
    And I visit the "Back Room Social" huddl page
    Then I should see "Back room, 222 West King Street, St. Augustine, FL"

  Scenario: An edited address still points to the chosen place
    Given the group "Riverside Runners" has a saved location "Alfred's" at "Back room, 222 West King Street, St. Augustine, FL" for place "place-alfreds"
    And the group "Riverside Runners" has a huddl "Back Room Social" at "Back room, 222 West King Street, St. Augustine, FL"
    When I visit the "Back Room Social" huddl page
    Then the map link for the huddl points to the place "place-alfreds"

  Scenario: Choosing another place after editing the address
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the venue "Alfred's" at "222 W King St, St. Augustine, FL 32084, USA"
    And I fill in "Address" with "Back room, 222 West King Street, St. Augustine, FL"
    And I change the place to the venue "Odd Birds" at "10 Anastasia Blvd, St. Augustine, FL 32080, USA"
    Then I am asked whether to replace my address
    And the address reads "Back room, 222 West King Street, St. Augustine, FL"
    When I click "Use the new place's address"
    Then the address reads "Odd Birds" then "10 Anastasia Blvd, St. Augustine, FL 32080, USA"

  Scenario: Keeping an edited address after choosing another place
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the venue "Alfred's" at "222 W King St, St. Augustine, FL 32084, USA"
    And I fill in "Address" with "Back room, 222 West King Street, St. Augustine, FL"
    And I change the place to the venue "Odd Birds" at "10 Anastasia Blvd, St. Augustine, FL 32080, USA"
    And I click "Keep my address"
    Then the address reads "Back room, 222 West King Street, St. Augustine, FL"

  Scenario: Two entries at the same place
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the venue "Hashrocket" at "320 1st St N, Jacksonville Beach, FL 32250, USA"
    And I fill in "Location name (optional)" with "Hashrocket"
    And I fill in "Address" with "Suite 711, 320 1st St N, Jacksonville Beach, FL"
    And I click "Save Address"
    And I click "Add Address"
    And I choose the venue "Hashrocket" at "320 1st St N, Jacksonville Beach, FL 32250, USA"
    And I fill in "Location name (optional)" with "Hashrocket"
    And I fill in "Address" with "Rooftop, 320 1st St N, Jacksonville Beach, FL"
    And I click "Save Address"
    And I visit the locations page for "Riverside Runners"
    Then I should see "Suite 711, 320 1st St N, Jacksonville Beach, FL"
    And I should see "Rooftop, 320 1st St N, Jacksonville Beach, FL"

  Scenario: Telling entries apart when scheduling
    Given the group "Riverside Runners" has a saved location "Hashrocket" at "Suite 711, 320 1st St N, Jacksonville Beach, FL" with coordinates 30.292, -81.39
    And the group "Riverside Runners" has a saved location "Hashrocket" at "Rooftop, 320 1st St N, Jacksonville Beach, FL" with coordinates 30.292, -81.39
    When I visit the new huddl page for "Riverside Runners"
    And I search the location picker for "Hashrocket"
    Then I should see "Suite 711, 320 1st St N, Jacksonville Beach, FL"
    And I should see "Rooftop, 320 1st St N, Jacksonville Beach, FL"

  Scenario: Editing the address of an existing entry
    Given the group "Riverside Runners" has a saved location "Alfred's" at "222 W King St, St. Augustine, FL 32084, USA" with coordinates 29.8921, -81.3139
    When I visit the locations page for "Riverside Runners"
    And I click "Edit"
    And I fill in "Address" with "Back room, 222 West King Street, St. Augustine, FL"
    And I click "Save"
    And I visit the locations page for "Riverside Runners"
    Then I should see "Back room, 222 West King Street, St. Augustine, FL"
