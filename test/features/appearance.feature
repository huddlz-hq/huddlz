@async @database @conn
Feature: Appearance preference
  As a user
  I want huddlz to follow my device's appearance, or to pick light or dark myself
  So that the app looks right wherever I read it

  Scenario: Signed-out visitors follow their device
    When I visit "/"
    Then the page should follow the device appearance

  Scenario: New users follow their device by default
    Given I am signed in as "theme-default@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    Then I should see "Appearance"
    And the page should follow the device appearance

  Scenario: User switches to light mode
    Given I am signed in as "theme-light@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    And I choose "Light"
    Then I should see "Appearance saved"
    And the page should use the "light" appearance

  Scenario: User switches back to their device's appearance
    Given I am signed in as "theme-system@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    And I choose "Dark"
    And I choose "System"
    Then the page should follow the device appearance
