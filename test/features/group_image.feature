@async @database @conn
Feature: Group Image Management
  As a group owner
  I want to upload and manage group images
  So that my group has a visual identity

  Background:
    Given the following users exist:
      | email                | role     | display_name    |
      | owner@example.com    | user     | Group Owner     |
      | member@example.com   | user     | Group Member    |
      | other@example.com    | user     | Other User      |

  # ===== Group Creation with Image =====

  Scenario: Owner can see image upload area when creating a group
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    Then I should see "Group Image"
    And I should see "Upload a banner image for your group"
    And I should see "Click to upload or drag and drop"
    And I should see "JPG, PNG, or WebP (max 5MB)"

  Scenario: Creating a group without an image
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    And I fill in "Group Name" with "No Image Group"
    And I fill in "Description" with "A group without an image"
    And I check "Public group (visible to everyone)"
    And I click "Create Group"
    Then I should see "Group created successfully"
    And I should see "No Image Group"

  Scenario: Creating a group with an image upload
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    And I fill in "Group Name" with "Image Test Group"
    And I fill in "Description" with "A group with an image"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "Image uploaded"
    When I click "Create Group"
    Then I should see "Group created successfully"
    And I should see "Image Test Group"
    And the group "Image Test Group" should have an image

  Scenario: Canceling a pending image before saving group
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    And I fill in "Group Name" with "Cancel Image Group"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "Image uploaded"
    When I cancel the pending image
    Then I should not see "Image uploaded"
    When I click "Create Group"
    Then I should see "Group created successfully"
    And the group "Cancel Image Group" should not have an image

  Scenario: Re-uploading replaces the pending image
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    And I fill in "Group Name" with "Replace Image Group"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "Image uploaded"
    When I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "Image uploaded"
    And there should be only one pending image for the current user

  # ===== Group Editing with Image =====

  Scenario: Owner can see image upload area when editing a group
    Given a public group "Edit Test Group" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for group "Edit Test Group"
    Then I should see "Group Image"
    And I should see "Upload a banner image for your group"

  Scenario: Owner can upload a new image for existing group
    Given a public group "Add Image Group" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for group "Add Image Group"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "New image uploaded. Save to apply."
    When I click "Save Changes"
    Then I should see "Group updated successfully"
    And the group "Add Image Group" should have an image

  Scenario: Owner can replace existing group image
    Given a public group "Replace Image Group" exists with owner "owner@example.com"
    And the group "Replace Image Group" has an image
    And I am signed in as "owner@example.com"
    When I visit the edit page for group "Replace Image Group"
    Then I should see "Current image"
    When I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "New image uploaded. Save to apply."
    When I click "Save Changes"
    Then I should see "Group updated successfully"
    And the group "Replace Image Group" should have an image

  Scenario: Owner can remove existing group image
    Given a public group "Remove Image Group" exists with owner "owner@example.com"
    And the group "Remove Image Group" has an image
    And I am signed in as "owner@example.com"
    When I visit the edit page for group "Remove Image Group"
    Then I should see "Current image"
    When I click "Remove image"
    Then I should see "Image removed"
    And the group "Remove Image Group" should not have an image

  Scenario: Canceling a pending image shows current image again
    Given a public group "Cancel Replace Group" exists with owner "owner@example.com"
    And the group "Cancel Replace Group" has an image
    And I am signed in as "owner@example.com"
    When I visit the edit page for group "Cancel Replace Group"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "New image uploaded. Save to apply."
    When I cancel the pending image
    Then I should see "Current image"
    And I should not see "New image uploaded"

  # ===== Group Image Display =====

  Scenario: Group image is displayed on group page
    Given a public group "Display Image Group" exists with owner "owner@example.com"
    And the group "Display Image Group" has an image
    When I visit the group page for "Display Image Group"
    Then I should see the group image

  Scenario: Group without image shows placeholder
    Given a public group "No Image Display Group" exists with owner "owner@example.com"
    When I visit the group page for "No Image Display Group"
    Then I should not see the group image

  # ===== Permissions =====

  Scenario: Non-owner cannot upload images for group
    Given a public group "Other Owner Group" exists with owner "owner@example.com"
    And I am signed in as "other@example.com"
    When I visit the edit page for group "Other Owner Group"
    Then I should be redirected to the group page

  Scenario: Member cannot upload images for group
    Given a public group "Member Test Group" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Member Test Group"
    And I am signed in as "member@example.com"
    When I visit the edit page for group "Member Test Group"
    Then I should be redirected to the group page

  # ===== Edge Cases =====

  Scenario: Form validation errors preserve pending image
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "Image uploaded"
    When I click "Create Group"
    Then I should see "is required"
    And I should see "Image uploaded"

  Scenario: Navigating away leaves orphaned pending image for cleanup
    Given I am signed in as "owner@example.com"
    When I visit "/groups/new"
    And I upload "test/fixtures/test_image.jpg" to "Group Image"
    Then I should see "Image uploaded"
    When I visit "/groups"
    Then there should be an orphaned pending image
