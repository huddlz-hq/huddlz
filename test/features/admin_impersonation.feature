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
