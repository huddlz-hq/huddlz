@async @database @conn
Feature: User Profile Management
  As a logged-in user
  I want to manage my profile
  So that I can control how others see me on the platform

  Background:
    Given the following users exist:
      | email                | role     | display_name    |
      | alice@example.com    | user     | BraveEagle726   |
    And I am signed in as "alice@example.com"

  Scenario: Viewing my profile
    When I visit "/profile"
    Then I should see "Profile Settings"
    And I should see my current display name
    And I should see "alice@example.com"

  Scenario: Updating my display name
    Given I am on my profile page
    When I fill in "Display Name" with "Alice Cooper"
    And I click the "Save Changes" button
    Then I should see "Display name updated successfully"
    And the display name field should contain "Alice Cooper"

  Scenario: Display name validation - empty
    Given I am on my profile page
    When I fill in "Display Name" with ""
    And I click the "Save Changes" button
    Then I should see "Failed to update display name. Please check the errors below."
    And I should not see "Display name updated successfully"

  Scenario: Display name validation - too long
    Given I am on my profile page
    When I fill in "Display Name" with "This is a very long display name that definitely exceeds the seventy character maximum length allowed"
    And I click the "Save Changes" button
    Then I should see "Failed to update display name. Please check the errors below."
    And I should not see "Display name updated successfully"

  Scenario: Accessing profile from navbar
    When I visit "/"
    Then I should see "huddlz"
    When I visit "/profile"
    Then I should see "Profile Settings"
    And I should see "Manage your profile information"

  Scenario: Setting home location with autocomplete
    Given I am on my profile page
    When I type "saint" in the location field
    Then I should see location suggestions
    When I select "Saint Augustine" from the location suggestions
    And I click the "Save Location" button
    Then I should see "Home location updated"

  Scenario: No location suggestions for unrecognized input
    Given I am on my profile page
    When I type "xyznonexistent" in the location field
    Then I should see "No locations found"