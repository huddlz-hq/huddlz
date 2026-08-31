@async @database @conn
Feature: Device-local Today boundaries

  Scenario: The device time zone determines Today
    Given my device time zone is "America/Los_Angeles"
    And I am signed in
    And I am going to a huddl whose start time falls today in "America/Los_Angeles"
    And that same instant falls tomorrow in UTC
    When I visit Calendar
    Then I see the huddl in Today

  Scenario: An overnight huddl appears on every local day it overlaps
    Given my device time zone is "America/New_York"
    And I am signed in
    And I am going to a huddl that starts at 11:00 PM today and ends at 1:00 AM tomorrow in my device time zone
    When I view Today before local midnight
    Then I see the huddl
    When I view Today after local midnight
    Then I see the huddl

  Scenario: A huddl that ended earlier today remains visible
    Given my device time zone is "America/New_York"
    And I am signed in
    And I went to a huddl that ended earlier today in my device time zone
    When I visit Calendar
    Then I see the huddl in Today
    And the huddl has the existing past treatment
