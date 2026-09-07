@async @database @conn @photo_compatibility
Feature: Existing cover upload clients
  Scenario: A host keeps using the established cover upload API
    Given a host with a huddl needing a cover
    When the host uploads a cover using the established API
    Then the cover is available and the established GraphQL upload remains available
