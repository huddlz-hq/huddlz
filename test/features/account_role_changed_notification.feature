@async @database
Feature: Account role changed notification email
  As a user
  I want to be told when an admin changes my account role
  So that I notice unexpected privilege changes

  Scenario: A notification email is sent when an admin promotes a user
    Given the following users exist:
      | email             | display_name | role  |
      | adm@example.com   | Adm          | admin |
      | regular@example.com | Reggie     | user  |
    When the admin "adm@example.com" updates "regular@example.com" to role "admin"
    Then a role-change notification should be sent to "regular@example.com" naming role "admin"

  Scenario: No email is sent when the role does not actually change
    Given the following users exist:
      | email             | display_name | role  |
      | adm@example.com   | Adm          | admin |
      | already@example.com | Al         | admin |
    When the admin "adm@example.com" updates "already@example.com" to role "admin"
    Then no role-change notification should be sent

  Scenario: An admin cannot change their own role
    Given the following users exist:
      | email             | display_name | role  |
      | self@example.com  | Solo         | admin |
    When the admin "self@example.com" tries to update "self@example.com" to role "user"
    Then the role update should be rejected
    And no role-change notification should be sent
