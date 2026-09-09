@async @database @conn @api_search_defaults
Feature: Home search location for API clients
  As a member using an API client
  I want to use my saved home search location
  So that I do not maintain a separate preference in each client

  Scenario: Discover my home search location
    Given I have saved Austin as my home search location
    When I request my search defaults with a bearer token and an API key
    Then both clients receive Austin and a 25 mile default radius

  Scenario Outline: Missing and incomplete home search locations
    Given my home search location is "<state>"
    When I request my search defaults with a bearer token and an API key
    Then both clients know there is no usable home search location

    Examples:
      | state             |
      | unset             |
      | cleared           |
      | missing latitude  |
      | missing longitude |
      | missing time zone |
      | invalid time zone |

  Scenario: Private profile access belongs to the authenticated member
    Given I have saved Austin as my home search location
    When clients request private profiles with different credentials
    Then only my credentials reveal my profile and home search location

  Scenario: Clients see changes without replacing their credentials
    Given I have saved Austin as my home search location
    When I change my home search location after clients have read my profile
    Then the same clients receive my updated home search location

  Scenario: Searching elsewhere does not change my home search location
    Given I have saved Austin as my home search location
    And public huddlz are available in Austin and New York
    When I search near home, near New York, and everywhere through the API
    Then each search uses the chosen area and my profile still defaults to Austin
