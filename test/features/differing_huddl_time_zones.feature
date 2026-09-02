@async @database @conn @issue406
Feature: Calendar and Huddl time presentation

  Scenario: A huddl is placed and presented in my Calendar time zone
    Given my Calendar time zone is "America/New_York"
    And I am going to a huddl at 9:00 PM in "America/Los_Angeles"
    And that instant falls on a different date in New York
    When I view the huddl in Calendar
    Then it appears on its New York date
    And the card's primary date and time use "America/New_York"
    And the card identifies 9:00 PM at the huddl
    And the detailed view presents only the authoritative huddl time

  Scenario: Matching time zones use one schedule time
    Given my Calendar and Huddl time zones are both "America/New_York"
    When I view the huddl
    Then I see one schedule time

  Scenario: Changing Calendar time preserves deliberate Calendar navigation
    Given I explicitly selected a future date and month
    When I change my Calendar time zone
    Then the selected date and month remain selected
    But an implicit current Day follows today in the new time zone
