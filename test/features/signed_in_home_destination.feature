@async @database @conn
Feature: Signed-in home destination

  Scenario: A signed-in user lands on Calendar Today
    Given I am signed in
    When I visit the application root
    Then I am taken to Calendar
    And Today is selected

  Scenario: A new signed-in user also lands on Calendar Today
    Given I am signed in
    And I have no group memberships
    And I have no Personal huddlz
    When I visit the application root
    Then I am taken to Calendar
    And Today is selected

  Scenario: An anonymous visitor keeps the existing landing page
    Given I am not signed in
    When I visit the application root
    Then I see the existing anonymous landing page
