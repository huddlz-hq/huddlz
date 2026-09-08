@async @database @conn @api_hosting_group
Feature: Identify the group hosting a huddl through the API
  As a person viewing a huddl in an API client
  I want to know which group is hosting it
  So that I can recognize the community organizing it

  Scenario: A visitor identifies a public huddl's host through GraphQL
    Given a public huddl hosted by "Brooklyn Coffee Club"
    When I request the huddl's hosting group through "GraphQL"
    Then the API identifies "Brooklyn Coffee Club" as the hosting group

  Scenario: A visitor identifies a public huddl's host through JSON:API
    Given a public huddl hosted by "Brooklyn Coffee Club"
    When I request the huddl's hosting group through "JSON:API"
    Then the API identifies "Brooklyn Coffee Club" as the hosting group

  Scenario Outline: A member identifies the group hosting a private huddl
    Given I belong to the private group hosting "Saturday Coffee"
    When I request the huddl's hosting group through "<api>"
    Then the API identifies "Brooklyn Coffee Club" as the hosting group

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario Outline: A former member can see a cancellation without seeing the private host
    Given I belong to the private group hosting "Saturday Coffee"
    And I have RSVP history for the cancelled huddl but have left its group
    When I request the huddl's hosting group through "<api>"
    Then the API returns the huddl with unavailable hosting information

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario Outline: An outsider cannot reveal a private huddl by requesting its host
    Given I belong to the private group hosting "Saturday Coffee"
    But I am requesting the host as "<viewer>"
    When I request the huddl's hosting group through "<api>"
    Then the API does not reveal the huddl or its hosting group

    Examples:
      | api      | viewer    |
      | GraphQL  | anonymous |
      | JSON:API | anonymous |
      | GraphQL  | nonmember |
      | JSON:API | nonmember |
