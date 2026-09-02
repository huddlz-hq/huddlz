@signed_in_home_destination @async @database @conn
Feature: Signed-in home destination

  Scenario: A signed-in user lands on Calendar Day
    Given I am signed in
    When I visit the application root
    Then I am taken to Calendar
    And the current date is selected

  Scenario: An anonymous visitor keeps the existing landing page
    Given I am not signed in
    When I visit the application root
    Then I see the existing anonymous landing page
