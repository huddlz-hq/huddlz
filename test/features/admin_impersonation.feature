@database @conn @admin_impersonation
Feature: Administrators troubleshoot as a user instead of editing as one
  As an administrator
  I want to see huddlz as a particular person sees it
  So that I can troubleshoot without holding editing rights over every group

  Background:
    Given the following users exist:
      | email                 | role  | display_name |
      | admin554@example.com  | admin | Admin Alex   |
      | other554@example.com  | admin | Admin Avery  |
      | owner554@example.com  | user  | Owner Olive  |
      | member554@example.com | user  | Member Maya  |
    And a public group "Portland Elixir" exists with owner "owner554@example.com"
    And "member554@example.com" is a member of "Portland Elixir"

  Scenario: An administrator cannot edit a group they do not organize
    Given I am signed in as "admin554@example.com"
    When I visit "/groups/portland-elixir/edit"
    Then I am told I cannot edit "Portland Elixir"
    And "admin554@example.com" cannot rename "Portland Elixir" through the API

  Scenario: An administrator who organizes a group keeps that role
    Given "admin554@example.com" is an organizer of "Portland Elixir"
    And I am signed in as "admin554@example.com"
    When I visit "/groups/portland-elixir/huddlz/new"
    Then I am offered to schedule a huddl
    And "admin554@example.com" cannot transfer ownership of "Portland Elixir"

  Scenario: An administrator views huddlz as a member
    Given I am signed in as "admin554@example.com"
    When I visit "/admin/users"
    And I choose to view as "member554@example.com"
    Then every page says I am viewing as "Member Maya"
    And the sidebar shows me as "Member Maya"
    When I visit "/admin"
    Then I should see "You don't have access to the admin area."

  Scenario: The impersonated session has only the member's rights
    Given I am viewing huddlz as "member554@example.com"
    When I visit "/groups/portland-elixir/edit"
    Then I am told I cannot edit "Portland Elixir"

  Scenario: Stopping returns the administrator to their own session
    Given I am viewing huddlz as "member554@example.com"
    When I stop viewing as "Member Maya"
    Then the sidebar shows me as "Admin Alex"
    And I am on the users page
    And no page says I am viewing as "Member Maya"

  Scenario: Only administrators can start viewing as someone
    Given I am signed in as "owner554@example.com"
    When I try to view as "member554@example.com"
    Then I should see "You don't have access to the admin area."

  Scenario: Administrators cannot be viewed as
    Given I am signed in as "admin554@example.com"
    When I visit "/admin/users"
    Then I am not offered to view as "other554@example.com"
    But I am offered to view as "owner554@example.com"

  Scenario: Start, stop and what happened in between are on record
    Given the in-person huddl "Kickoff" in "Portland Elixir" is upcoming with 0 RSVPs
    And I am viewing huddlz as "member554@example.com"
    When I RSVP to "Kickoff"
    And I stop viewing as "Member Maya"
    Then the record shows "admin554@example.com" viewed as "member554@example.com" and stopped
    And the RSVP by "member554@example.com" to "Kickoff" is attributed to that viewing
