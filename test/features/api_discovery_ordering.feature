@async @database @conn @api_discovery_ordering
Feature: Discovery ordering for API callers
  As a visitor using the discovery API without signing in
  I want to choose between huddlz starting soonest and newly created huddlz
  So that I can find my next huddl

  Background:
    Given these public upcoming huddlz are available for API discovery:
      | title          | starts in days | created days ago |
      | Weekend Walk   | 7              | 3                |
      | Morning Coffee | 1              | 2                |
      | Board Games    | 4              | 1                |

  Scenario Outline: A visitor chooses discovery ordering
    When I discover upcoming huddlz through the API ordered by "<ordering>" without signing in
    Then the discovery API should return huddlz in this order:
      | title    |
      | <first>  |
      | <second> |
      | <third>  |

    Examples:
      | ordering     | first          | second         | third        |
      | starts_at    | Morning Coffee | Board Games    | Weekend Walk |
      | -inserted_at | Board Games    | Morning Coffee | Weekend Walk |

  Scenario: Discovery defaults to huddlz starting soonest
    When I discover upcoming huddlz through the API without choosing an ordering or signing in
    Then the discovery API should return huddlz in this order:
      | title          |
      | Morning Coffee |
      | Board Games    |
      | Weekend Walk   |
