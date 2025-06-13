@conn
Feature: View Past Huddlz
  As a user
  I want to see past huddlz
  So that I can see what events have already happened

  Background:
    Given the following users exist:
      | email                | display_name | role     |
      | member@example.com   | Test Member  | regular  |
      | nonmember@example.com| Non Member   | regular  |
    And there are past and future huddlz in the system

  Scenario: View past huddlz in public groups
    When I visit the home page
    And I select "Past Events" from the date filter
    Then I should see past huddlz
    And I should not see future huddlz in the past section
    And the past huddlz should be sorted newest first

  Scenario: View past huddlz as a group member
    Given I am signed in as "member@example.com"
    And I am a member of a private group with past huddlz
    When I visit the home page
    And I select "Past Events" from the date filter
    Then I should see past huddlz from my private group
    And I should see past huddlz from public groups

  Scenario: Non-members cannot see past huddlz in private groups
    Given I am signed in as "nonmember@example.com"
    And there is a private group with past huddlz I'm not a member of
    When I visit the home page
    And I select "Past Events" from the date filter
    Then I should not see past huddlz from the private group
    But I should see past huddlz from public groups

  Scenario: Anonymous users can see past public huddlz
    When I visit the home page
    And I select "Past Events" from the date filter
    Then I should see past huddlz from public groups
    And I should not see any private huddlz