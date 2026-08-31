@async @database @conn @empty_today_guidance
Feature: Empty Today guidance

  Scenario: Empty Today shows the next three Calendar entries
    Given I am signed in
    And I have no Calendar huddlz today
    And I have four future Calendar huddlz
    When I visit Calendar
    Then I see the shared empty Today message
    And I see a "Coming up" section
    And I see the next three future huddlz in chronological order
    And I do not see the fourth future huddl
    And I can navigate to Discover

  Scenario: Empty Today without future huddlz omits Coming up
    Given I am signed in
    And I have no Calendar huddlz today
    And I have no future Calendar huddlz
    When I visit Calendar
    Then I see the shared empty Today message
    And I do not see a "Coming up" section
    And I can navigate to Discover
