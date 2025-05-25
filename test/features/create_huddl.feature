Feature: Create Huddl
  As a group owner or organizer
  I want to create huddlz for my groups
  So that members know when and where to meet

  Background:
    Given the following users exist:
      | email                 | role     | display_name |
      | owner@example.com     | verified | Group Owner  |
      | organizer@example.com | verified | Organizer    |
      | member@example.com    | verified | Member       |
      | regular@example.com   | regular  | Regular User |
    And the following groups exist:
      | name           | owner_email       | is_public |
      | Tech Meetup    | owner@example.com | true      |
      | Private Group  | owner@example.com | false     |
    And the following group memberships exist:
      | group_name   | user_email            | role      |
      | Tech Meetup  | organizer@example.com | organizer |
      | Tech Meetup  | member@example.com    | member    |

  Scenario: Owner creates an in-person huddl
    Given I am signed in as "owner@example.com"
    When I visit the "Tech Meetup" group page
    Then I should see a "Create Huddl" button
    When I click "Create Huddl"
    Then I should be on the new huddl page for "Tech Meetup"
    When I fill in the huddl form with:
      | Field             | Value                        |
      | Title             | Monthly Tech Talk            |
      | Description       | Discussion about new tech    |
      | Start Date & Time | tomorrow at 6:00 PM         |
      | End Date & Time   | tomorrow at 8:00 PM         |
      | Event Type        | In-Person                   |
      | Physical Location | 123 Main St, Tech City      |
    And I submit the form
    Then I should be redirected to the "Tech Meetup" group page
    And I should see "Huddl created successfully!"

  Scenario: Organizer creates a virtual huddl
    Given I am signed in as "organizer@example.com"
    When I visit the "Tech Meetup" group page
    Then I should see a "Create Huddl" button
    When I click "Create Huddl"
    Then I should be on the new huddl page for "Tech Meetup"
    When I fill in the huddl form with:
      | Field             | Value                        |
      | Title             | Virtual Code Review          |
      | Description       | Remote code review session   |
      | Start Date & Time | tomorrow at 3:00 PM         |
      | End Date & Time   | tomorrow at 4:00 PM         |
      | Event Type        | Virtual                     |
      | Virtual Link      | https://zoom.us/j/123456    |
    And I submit the form
    Then I should be redirected to the "Tech Meetup" group page
    And I should see "Huddl created successfully!"

  Scenario: Creating a hybrid huddl shows both location fields
    Given I am signed in as "owner@example.com"
    When I visit the new huddl page for "Tech Meetup"
    Then I should see "Physical Location" field
    And I should not see "Virtual Meeting Link" field
    When I select "Hybrid (Both In-Person and Virtual)" from "Event Type"
    Then I should see "Physical Location" field
    And I should see "Virtual Meeting Link" field

  Scenario: Private groups create private huddls only
    Given I am signed in as "owner@example.com"
    When I visit the new huddl page for "Private Group"
    Then I should not see a checkbox for "Make this a private event"
    And I should see "This will be a private event (private groups can only create private events)"
    When I fill in the huddl form with:
      | Field             | Value                        |
      | Title             | Private Meeting              |
      | Description       | Members only                 |
      | Start Date & Time | tomorrow at 2:00 PM         |
      | End Date & Time   | tomorrow at 3:00 PM         |
      | Event Type        | In-Person                   |
      | Physical Location | Secret Location              |
    And I submit the form
    Then the huddl should be created as private

  Scenario: Regular member cannot create huddl
    Given I am signed in as "member@example.com"
    When I visit the "Tech Meetup" group page
    Then I should not see a "Create Huddl" button
    When I try to visit the new huddl page for "Tech Meetup"
    Then I should be redirected to the "Tech Meetup" group page
    And I should see "You don't have permission to create huddlz for this group"

  Scenario: Form validation shows errors
    Given I am signed in as "owner@example.com"
    When I visit the new huddl page for "Tech Meetup"
    And I submit the form without filling it
    Then I should see validation errors for required fields
    And I should remain on the new huddl page