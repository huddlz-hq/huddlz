@async @database @conn @account_required_return_to
Feature: Signing in from a page that needs an account returns me there
  As a person who opened a link to a page that needs an account
  I want signing in to bring me back to that page
  So that signing in does not cost me the page I came for

  Background:
    Given the following users exist:
      | email                       | role  | display_name |
      | guest+required@example.com  | user  | Guest        |
      | admin+required@example.com  | admin | Admin        |
    And the user "guest+required@example.com" has password "Password123!"
    And the user "admin+required@example.com" has password "Password123!"

  Scenario: A page that needs an account returns me to it after signing in
    Given I start in a signed-out browser
    When I arrive at "/notifications"
    And I sign in as "guest+required@example.com" with password "Password123!"
    Then I should be back at "/notifications"

  Scenario: An admin page returns an admin to it after signing in
    Given I start in a signed-out browser
    When I arrive at "/admin/users"
    And I sign in as "admin+required@example.com" with password "Password123!"
    Then I should be back at "/admin/users"

  Scenario: Discover's huddlz I am attending returns me to that filter after signing in
    Given I start in a signed-out browser
    When I arrive at "/discover?yours=attending"
    And I sign in as "guest+required@example.com" with password "Password123!"
    Then I should be back at "/discover?yours=attending"
