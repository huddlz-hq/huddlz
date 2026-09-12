@database @conn @admin_overview
Feature: Admin platform overview
  As an administrator
  I want one page with platform-wide figures
  So that I can tell whether huddlz is growing and being used

  Background:
    Given the following users exist:
      | email                 | role  | display_name |
      | admin553@example.com  | admin | Admin Alex   |
      | owner553@example.com  | user  | Owner Olive  |
      | member553@example.com | user  | Member Maya  |
    And a public group "Portland Elixir" exists with owner "owner553@example.com"
    And a public group "Founder Coffee" exists with owner "owner553@example.com"

  Scenario: Only administrators can open the overview
    Given I am signed in as "owner553@example.com"
    When I visit "/admin"
    Then I should see "You don't have access to the admin area."

  Scenario: User management lives under Users
    Given I am signed in as "admin553@example.com"
    When I visit "/admin/users"
    Then I should see "Owner Olive"
    And I can change the role of "member553@example.com"
