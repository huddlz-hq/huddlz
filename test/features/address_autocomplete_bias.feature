@address_bias @async @database @conn
Feature: Address suggestions near the group
  A group's address book favors places near its home city
  while still allowing meeting places farther away.

  Background:
    Given the following users exist:
      | email                          | role     | display_name |
      | address-bias-owner@example.com | verified | Group Owner  |
    And I am signed in as "address-bias-owner@example.com"
    And my group "Saint Augustine Neighbors" is based in "America/New_York"

  Scenario Outline: Adding an address favors the group's home city
    When I add an address from "<entry point>"
    And I search the address book for "222 W King"
    Then the first address suggestion should be "222 W King St, Saint Augustine, FL"

    Examples:
      | entry point       |
      | the address book  |
      | a new huddl       |
      | an existing huddl |
