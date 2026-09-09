@database @conn
Feature: First-run empty states
  A new account has no RSVPs, no groups and an empty calendar. Rather than
  saying "nothing here", each empty page explains what it will hold and
  offers the one action that fills it. Once someone has history, the same
  page goes quiet instead of instructive.

  Background:
    Given the following users exist:
      | email                | display_name | role |
      | newcomer@example.com | Ada Park     | user |
    And I am signed in as "newcomer@example.com"

  Scenario: A newcomer's My huddlz sends them to find a huddl
    When I visit "/my-huddlz"
    Then I should see "No upcoming RSVPs yet"
    And I should see "Find a huddl worth showing up to and it will land here."
    When I click link "Find a huddl"
    Then I should see "Browse huddlz"

  Scenario: A newcomer's My groups offers both ways in
    When I visit "/my-groups"
    Then I should see "No groups yet"
    And I should see "Groups are where huddlz come from."
    And I am offered "Browse groups" and "Start your own"
    When I click link "Start your own"
    Then I should see "Create a group"

  Scenario: A newcomer's calendar explains what fills it
    When I visit "/calendar"
    Then I should see "Your calendar is empty"
    And I should see "Huddlz you RSVP to show up here"
    When I click link "Find a huddl"
    Then I should see "Browse huddlz"

  Scenario: Someone who has attended before sees a quieter My huddlz
    Given I attended a huddl last month
    When I visit "/my-huddlz"
    Then I should see "Nothing coming up"
    And I should not see "No upcoming RSVPs yet"
    And I should see "Browse huddlz"

  Scenario: The owner of a new group is invited to schedule its first huddl
    Given I own a group with no huddlz
    When I visit my group's page
    Then I should see "Nothing scheduled"
    And I should see "Members will see your next huddl here."
    When I click link "Schedule a huddl"
    Then I should see "Schedule a huddl"
