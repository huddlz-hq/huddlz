@async @database @conn @issue404
Feature: Physical venue huddl time zones

  Scenario Outline: A venue determines the huddl time zone
    Given I am scheduling a <type> huddl
    When I select a venue in Denver
    Then "America/Denver" is shown as the huddl time zone
    And I cannot replace it with an unrelated time zone
    And the huddl is saved at the entered Denver wall-clock time

    Examples:
      | type     |
      | physical |
      | hybrid   |

  Scenario: An unresolved venue cannot be repaired with a manual time zone
    Given I select a venue whose time zone cannot be resolved
    When I try to save the huddl
    Then I am asked to choose a resolvable saved venue
    And the huddl is not saved
