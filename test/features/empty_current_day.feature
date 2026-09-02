@async @database @conn @empty_current_day
Feature: Empty current Day guidance

  Scenario: Empty current Day shows the next three Calendar entries
    Given I am signed in
    And I have no Calendar huddlz today
    And I have four future Calendar huddlz
    When I visit Calendar
    Then I see the shared empty current Day message
    And I see a "Coming up" section
    And I see the next three future huddlz in chronological order
    And I do not see the fourth future huddl
    And I can navigate to Discover

  Scenario: Empty current Day without future huddlz omits Coming up
    Given I am signed in
    And I have no Calendar huddlz today
    And I have no future Calendar huddlz
    When I visit Calendar
    Then I see the shared empty current Day message
    And I do not see a "Coming up" section
    And I can navigate to Discover
