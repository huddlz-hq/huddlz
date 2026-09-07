@browser_smoke @mobile @navigation_browser
Feature: Mobile navigation in a narrow browser
  Scenario: The drawer traps focus and restores a usable page after dismissal and navigation
    Given I have opened my profile in a browser
    When I open mobile navigation with the keyboard
    Then the drawer contains focus and the page behind it is inert
    When I close mobile navigation with Escape
    Then focus returns to the navigation trigger and the page is usable
    When I reopen mobile navigation and visit My groups
    Then My groups loads with the drawer closed and can reopen navigation
