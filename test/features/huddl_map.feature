@huddl_map @async @database @conn
Feature: The huddl page shows where the huddl is on a map
  As someone going to a huddl
  I want to see its location on a map
  So I know where to go at a glance

  Background:
    Given the following users exist:
      | email                     | role     | display_name |
      | owner+map@example.com     | verified | Group Owner  |
    And a public group "Riverside Runners" exists with owner "owner+map@example.com"
    And I am signed in as "owner+map@example.com"

  Scenario: An in-person huddl at a looked-up place
    Given the group "Riverside Runners" has a saved location "Starbucks Coffee Company" at "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA" for place "place-starbucks-9801"
    And the group "Riverside Runners" has a huddl "Coffee Run" at "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"
    When I visit the "Coffee Run" huddl page
    Then I see a map of the place "place-starbucks-9801"

  Scenario: An older huddl without a known place
    Given the group "Riverside Runners" has a saved location "Old clubhouse" at "Old Saint Augustine Road, Jacksonville, FL, USA" with coordinates 30.1712, -81.6021
    And the group "Riverside Runners" has a huddl "Clubhouse Run" at "Old Saint Augustine Road, Jacksonville, FL, USA"
    When I visit the "Clubhouse Run" huddl page
    Then I see a map at the coordinates 30.1712, -81.6021

  Scenario: A virtual huddl
    Given the group "Riverside Runners" has a virtual huddl "Online Planning"
    When I visit the "Online Planning" huddl page
    Then I see no map
