Feature: Cucumber setup
  Scenario: Cucumber runs a basic test
    Given the system is ready
    When I run a smoke test
    Then it should pass
