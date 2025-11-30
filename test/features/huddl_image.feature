@async @database @conn
Feature: Huddl Image Management
  As a group owner or organizer
  I want to upload images for huddlz
  So that my huddlz have visual identity

  Background:
    Given the following users exist:
      | email                | role     | display_name    |
      | owner@example.com    | user     | Group Owner     |
      | organizer@example.com| user     | Organizer       |
      | member@example.com   | user     | Group Member    |

  # ===== Huddl Creation with Image =====

  Scenario: Owner can see image upload area when creating a huddl
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the new huddl page for group "Tech Meetup"
    Then I should see "Huddl Image"
    And I should see "Upload a banner image"
    And I should see "Click to upload or drag and drop"

  Scenario: Creating a huddl without an image falls back to group image
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the group "Tech Meetup" has an image
    And I am signed in as "owner@example.com"
    When I visit the new huddl page for group "Tech Meetup"
    And I fill in "Title" with "Code Review Session"
    And I fill in "Description" with "Weekly code review"
    And I select "In Person" from "Event Type"
    And I fill in "Location" with "Conference Room A"
    And I fill in the date field with tomorrow's date
    And I fill in the start time with "10:00"
    And I select a duration of "60" minutes
    And I click "Create Huddl"
    Then I should see "Huddl created successfully"
    And the huddl "Code Review Session" should use the group image

  Scenario: Creating a huddl with its own image
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the group "Tech Meetup" has an image
    And I am signed in as "owner@example.com"
    When I visit the new huddl page for group "Tech Meetup"
    And I fill in "Title" with "Workshop"
    And I fill in "Description" with "Hands-on workshop"
    And I select "In Person" from "Event Type"
    And I fill in "Location" with "Lab"
    And I upload "test/fixtures/test_image.jpg" to "Huddl Image"
    Then I should see "Image uploaded"
    When I fill in the date field with tomorrow's date
    And I fill in the start time with "14:00"
    And I select a duration of "120" minutes
    And I click "Create Huddl"
    Then I should see "Huddl created successfully"
    And the huddl "Workshop" should have its own image

  # ===== Huddl Editing with Image =====

  Scenario: Owner can see image upload area when editing a huddl
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the following huddl exists in "Tech Meetup":
      | title          | description | event_type | physical_location | creator              |
      | Existing Huddl | Test desc   | in_person  | Test Location     | owner@example.com    |
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Existing Huddl"
    Then I should see "Huddl Image"
    And I should see "Upload a banner image"

  Scenario: Owner can upload a new image for existing huddl
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the following huddl exists in "Tech Meetup":
      | title        | description | event_type | physical_location | creator              |
      | Add Image    | Test desc   | in_person  | Test Location     | owner@example.com    |
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Add Image"
    And I upload "test/fixtures/test_image.jpg" to "Huddl Image"
    Then I should see "New image uploaded. Save to apply."
    When I click "Save Changes"
    Then I should see "Huddl updated successfully"
    And the huddl "Add Image" should have its own image

  Scenario: Owner can remove existing huddl image to fallback to group
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the group "Tech Meetup" has an image
    And the following huddl exists in "Tech Meetup":
      | title            | description | event_type | physical_location | creator              |
      | Remove Image     | Test desc   | in_person  | Test Location     | owner@example.com    |
    And the huddl "Remove Image" has an image
    And I am signed in as "owner@example.com"
    When I visit the edit page for huddl "Remove Image"
    Then I should see "Current image"
    When I click "Remove image"
    Then I should see "Image removed"
    And the huddl "Remove Image" should use the group image

  # ===== Organizer Permissions =====

  Scenario: Organizer can upload images for huddl
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And "organizer@example.com" is an organizer of "Tech Meetup"
    And I am signed in as "organizer@example.com"
    When I visit the new huddl page for group "Tech Meetup"
    And I fill in "Title" with "Organizer Huddl"
    And I fill in "Description" with "Created by organizer"
    And I select "Virtual" from "Event Type"
    And I fill in "Virtual Meeting Link" with "https://meet.example.com"
    And I upload "test/fixtures/test_image.jpg" to "Huddl Image"
    Then I should see "Image uploaded"
    When I fill in the date field with tomorrow's date
    And I fill in the start time with "15:00"
    And I select a duration of "60" minutes
    And I click "Create Huddl"
    Then I should see "Huddl created successfully"
    And the huddl "Organizer Huddl" should have its own image

  # ===== Image Display Fallback =====

  Scenario: Huddl without image displays group image on show page
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the group "Tech Meetup" has an image
    And the following huddl exists in "Tech Meetup":
      | title          | description | event_type | physical_location | creator              |
      | No Image Huddl | Test desc   | in_person  | Test Location     | owner@example.com    |
    When I visit the huddl page for "No Image Huddl"
    Then I should see the group fallback image

  Scenario: Huddl with image displays its own image
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And the group "Tech Meetup" has an image
    And the following huddl exists in "Tech Meetup":
      | title          | description | event_type | physical_location | creator              |
      | Has Image      | Test desc   | in_person  | Test Location     | owner@example.com    |
    And the huddl "Has Image" has an image
    When I visit the huddl page for "Has Image"
    Then I should see the huddl image

  Scenario: Huddl without image and no group image shows placeholder
    Given a public group "No Images Group" exists with owner "owner@example.com"
    And the following huddl exists in "No Images Group":
      | title          | description | event_type | physical_location | creator              |
      | Placeholder    | Test desc   | in_person  | Test Location     | owner@example.com    |
    When I visit the huddl page for "Placeholder"
    Then I should not see an image on the huddl page

  # ===== Member Permissions =====

  Scenario: Regular member cannot edit huddl images
    Given a public group "Tech Meetup" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Tech Meetup"
    And the following huddl exists in "Tech Meetup":
      | title          | description | event_type | physical_location | creator              |
      | Member Test    | Test desc   | in_person  | Test Location     | owner@example.com    |
    And I am signed in as "member@example.com"
    When I visit the edit page for huddl "Member Test"
    Then I should be redirected away from the edit page
