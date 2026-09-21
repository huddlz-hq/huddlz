@full_address_lookup @async @database @conn
Feature: Full addresses for looked-up places
  As a group organizer
  I want a searched street or venue saved with its full address
  So attendees are sent to exactly the right place on the map

  Background:
    Given the following users exist:
      | email                             | role     | display_name |
      | owner+full-address@example.com    | verified | Group Owner  |
    And a public group "Riverside Runners" exists with owner "owner+full-address@example.com"
    And I am signed in as "owner+full-address@example.com"

  Scenario: Searching by street saves the full address
    When I visit the locations page for "Riverside Runners"
    And I click "Add Address"
    And I choose the place "Old Saint Augustine Road, Jacksonville, FL, USA" with full address "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    And I click "Save Address"
    And I visit the locations page for "Riverside Runners"
    Then I should see "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    And I should not see "Old Saint Augustine Road, Jacksonville, FL, USA"

  Scenario: A huddl at a looked-up place links to exactly that place on the map
    Given the group "Riverside Runners" has a saved location "Starbucks Coffee Company" at "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA" for place "place-starbucks-9801"
    And the group "Riverside Runners" has a huddl "Coffee Run" at "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    When I visit the "Coffee Run" huddl page
    Then the map link for the huddl points to the place "place-starbucks-9801"

  Scenario: A huddl at an older saved address links to its coordinates
    Given the group "Riverside Runners" has a saved location "Old clubhouse" at "Old Saint Augustine Road, Jacksonville, FL, USA" with coordinates 30.1712, -81.6021
    And the group "Riverside Runners" has a huddl "Clubhouse Run" at "Old Saint Augustine Road, Jacksonville, FL, USA"
    When I visit the "Clubhouse Run" huddl page
    Then the map link for the huddl points to the coordinates 30.1712, -81.6021
