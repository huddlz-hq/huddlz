@database @conn @copy_huddl @remote_storage
Feature: Preview a copied cover stored remotely
  Scenario: The copied cover is visible before saving
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And that huddl has a cover image
    When I visit that huddl and choose to copy it
    Then the form shows a copy of the original's cover
