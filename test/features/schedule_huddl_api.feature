@async @database @conn @schedule_huddl_api
Feature: Schedule a huddl through the API
  As an organizer using an API client
  I want a huddl that has already started to be refused
  So that the huddlz I schedule are ones people can still attend

  Scenario Outline: A huddl cannot start in the past
    Given I organize a group as an API client
    When I schedule a virtual huddl through "<api>" starting an hour ago
    Then the huddl is refused because "starts_at" "must be in the future"
    And my group has no huddlz

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario Outline: A huddl can start later today
    Given I organize a group as an API client
    When I schedule a virtual huddl through "<api>" starting an hour from now
    Then my group has that huddl

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |
