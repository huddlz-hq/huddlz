@browser_smoke @appearance_browser
Feature: Appearance menu in a browser
  Scenario: Switching appearance from the header with the keyboard
    Given I have opened my agenda in a browser
    When I open the appearance menu with the keyboard
    And I pick "Dark" with the keyboard
    Then the page uses the dark appearance and the menu is closed
    When I open the appearance menu with the keyboard
    And I press Escape
    Then the menu is closed and focus is back on its trigger
