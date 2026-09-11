@browser_smoke @short @sidebar_browser
Feature: The sidebar scrolls as one on short screens
  Scenario: Every sidebar control can be reached on a short screen
    Given I have opened my agenda in a browser with enough groups to overflow the sidebar
    Then the sidebar is one scroll region
    When I tab through to Sign out
    Then Sign out is scrolled into view
    When I scroll the lower sidebar back to the top
    Then the top navigation is in view and the account area has scrolled away
    And the page behind the sidebar is still usable
