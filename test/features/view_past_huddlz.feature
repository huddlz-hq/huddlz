@async @database @conn
Feature: View Past Huddlz on Group Pages
  As a user
  I want to see past huddlz on group pages
  So that I can see what events have already happened in specific groups

  Background:
    Given the following users exist:
      | email                | display_name | role     |
      | member@example.com   | Test Member  | regular  |
      | nonmember@example.com| Non Member   | regular  |
    And there are groups with past and future huddlz in the system

  Scenario: View past huddlz in public groups
    When I visit a public group page
    And I click on the "Past Events" tab
    Then I should see past huddlz for that group
    And I should not see future huddlz in the past section
    And the past huddlz should be sorted newest first

  Scenario: View past huddlz as a group member
    Given I am signed in as "member@example.com"
    And I am a member of a private group with past huddlz
    When I visit that private group page
    And I click on the "Past Events" tab
    Then I should see past huddlz from my private group

  Scenario: Non-members cannot see private groups
    Given I am signed in as "nonmember@example.com"
    And there is a private group with past huddlz I'm not a member of
    When I try to visit that private group page
    Then I should be redirected to the groups index
    And I should see an error message

  Scenario: Anonymous users can see past public huddlz
    When I visit a public group page
    And I click on the "Past Events" tab
    Then I should see past huddlz from that public group

  Scenario: Pagination works for past events
    Given there is a public group with many past huddlz
    When I visit that group page
    And I click on the "Past Events" tab
    Then I should see pagination controls
    And I should see at most 10 past events per page