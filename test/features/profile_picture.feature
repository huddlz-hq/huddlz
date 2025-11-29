@async @database @conn
Feature: Profile Picture Management
  As a logged-in user
  I want to upload and manage my profile picture
  So that other users can recognize me on the platform

  Background:
    Given the following users exist:
      | email                | role     | display_name    |
      | alice@example.com    | user     | Alice User      |
    And I am signed in as "alice@example.com"

  Scenario: Viewing profile picture upload area
    When I visit "/profile"
    Then I should see "Profile Picture"
    And I should see "Upload a profile picture to personalize your account"
    And I should see "Click to upload or drag and drop"
    And I should see "JPG, PNG, or WebP (max 5MB)"

  Scenario: Profile shows fallback avatar when no picture is uploaded
    When I visit "/profile"
    Then I should see the avatar fallback showing initials

  Scenario: User can see remove button only when they have a profile picture
    When I visit "/profile"
    Then I should not see "Remove"

  Scenario: Viewing the profile picture card structure
    When I visit "/profile"
    Then I should see "Profile Settings"
    And I should see "Profile Picture"
    And I should see "Account Information"
    And I should see "Display Name"

  Scenario: Profile picture appears in navbar when user has one
    Given the following profile pictures exist:
      | user_email          | storage_path                                      |
      | alice@example.com   | /uploads/profile_pictures/alice/avatar.jpg        |
    When I visit "/"
    Then I should see the navbar avatar with image

  Scenario: Navbar shows initials when user has no profile picture
    When I visit "/"
    Then I should see the navbar avatar with initials "AU"

  Scenario: Profile picture appears in group members section
    Given the following groups exist:
      | name          | slug          | owner_email       | visibility |
      | Test Group    | test-group    | alice@example.com | public     |
    And the following profile pictures exist:
      | user_email          | storage_path                                      |
      | alice@example.com   | /uploads/profile_pictures/alice/avatar.jpg        |
    When I visit "/groups/test-group"
    Then I should see the member avatar with image

  Scenario: Profile picture appears for group owner in details section
    Given the following groups exist:
      | name          | slug          | owner_email       | visibility |
      | Test Group    | test-group    | alice@example.com | public     |
    And the following profile pictures exist:
      | user_email          | storage_path                                      |
      | alice@example.com   | /uploads/profile_pictures/alice/avatar.jpg        |
    When I visit "/groups/test-group"
    Then I should see the owner avatar with image

  Scenario: Profile picture appears for huddl creator
    Given the following groups exist:
      | name          | slug          | owner_email       | visibility |
      | Test Group    | test-group    | alice@example.com | public     |
    And a huddl "Test Huddl" exists in "Test Group" created by "alice@example.com"
    And the following profile pictures exist:
      | user_email          | storage_path                                      |
      | alice@example.com   | /uploads/profile_pictures/alice/avatar.jpg        |
    When I visit the huddl "Test Huddl" page
    Then I should see the creator avatar with image
