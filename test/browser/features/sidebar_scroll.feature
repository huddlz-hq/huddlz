@browser_smoke @short @sidebar_browser
Feature: The sidebar scrolls as one on short screens
  Scenario: Every sidebar control can be reached on a short screen
    Given I have opened my agenda in a browser with enough groups to overflow the sidebar
    Then the sidebar is one scroll region
    And the brand and account rows keep their height
    When I tab through to Sign out
    Then Sign out is scrolled into view
    When I scroll up with the wheel over the account area
    Then the top navigation is in view and the account area has scrolled away
    When I scroll down with the wheel over the top navigation
    Then Sign out is scrolled into view
    And the page behind the sidebar has not moved and is still usable
