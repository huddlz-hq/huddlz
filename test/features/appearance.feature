@async @database @conn
Feature: Appearance preference
  As a user
  I want huddlz to follow my device's appearance, or to pick light or dark myself from the header
  So that the app looks right wherever I read it

  Scenario: Signed-out visitors follow their device
    When I visit "/"
    Then the page should follow the device appearance
    And there is no appearance menu

  Scenario: New users follow their device by default
    Given I am signed in as "theme-default@example.com" with password "Password123!"
    When I visit "/agenda"
    Then the appearance menu marks "System" as current
    And the page should follow the device appearance

  Scenario: User switches to light mode from the header
    Given I am signed in as "theme-light@example.com" with password "Password123!"
    When I visit "/agenda"
    And I choose the "Light" appearance from the header
    Then the appearance menu marks "Light" as current
    And the page should use the "light" appearance
    When I visit "/discover"
    Then the page should use the "light" appearance

  Scenario: User switches back to their device's appearance
    Given I am signed in as "theme-system@example.com" with password "Password123!"
    When I visit "/agenda"
    And I choose the "Dark" appearance from the header
    And I choose the "System" appearance from the header
    Then the page should follow the device appearance
