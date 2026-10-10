@sign_in_return_browser
Feature: Returning after password recovery
  Scenario: Finish password recovery in the same browser
    Given I am signed out looking at a public huddl in a browser
    When I choose the header Sign in in a browser
    And I recover my password through its email in this browser
    Then I return to that huddl without reserving a spot in a browser
