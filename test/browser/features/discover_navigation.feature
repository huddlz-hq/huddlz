@browser_smoke
Feature: Discover over live navigation
  Scenario: Following Discover from the sidebar fills the results in place
    Given a public huddl titled "Riverside Sketch Walk" is upcoming
    And I have opened my agenda in a browser
    When I follow Discover in the sidebar
    Then the discover results arrive without a page load
