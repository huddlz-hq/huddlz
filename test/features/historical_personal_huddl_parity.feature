@historical_personal_huddl_parity @async @database @conn
Feature: Historical Personal huddl parity

  Scenario: A past Personal huddl remains reachable through Calendar
    Given I am signed in
    And I hosted, attended, or was waitlisted for a past huddl
    When I navigate Calendar to the huddl's past date
    Then I see the huddl once
    And I see its Personal relationship marker
    When I select the huddl card
    Then I am taken to the huddl detail page

  Scenario: A past Group opportunity remains reachable through its group
    Given I am an accepted member of a group
    And the group has a past huddl that I never responded to
    When I visit the group and browse its huddlz
    Then I can find the past huddl using the group's existing behavior
