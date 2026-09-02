@async @database @conn
Feature: Browser-derived Calendar time-zone Day boundaries

  Scenario: The browser time zone determines the current Day in Automatic mode
    Given my browser time zone is "America/Los_Angeles"
    And I am signed in
    And I am going to a huddl whose start time falls today in "America/Los_Angeles"
    And that same instant falls tomorrow in UTC
    When I visit Calendar
    Then I see the huddl in Day

  Scenario: An overnight huddl appears on every local day it overlaps
    Given my browser time zone is "America/New_York"
    And I am signed in
    And I am going to a huddl that starts at 11:00 PM today and ends at 1:00 AM tomorrow in my browser time zone
    When I view Day before local midnight
    Then I see the huddl
    When I view Day after local midnight
    Then I see the huddl

  Scenario: A huddl that ended earlier today remains visible
    Given my browser time zone is "America/New_York"
    And I am signed in
    And I went to a huddl that ended earlier today in my browser time zone
    When I visit Calendar
    Then I see the huddl in Day
    And the huddl has the existing past treatment
