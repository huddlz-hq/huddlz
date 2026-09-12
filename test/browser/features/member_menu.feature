@browser_smoke @member_menu_browser
Feature: Member menu in a browser
  Scenario: Working a member's menu with the keyboard
    Given I have opened a group's roster in a browser
    When I open the menu for "Member Maya" with the keyboard
    And I press Escape
    Then the member menu is closed and focus is back on its button
    When I open the menu for "Member Maya" with the keyboard
    And I choose "Promote to organizer" with the keyboard
    Then the promotion confirmation is open and the menu is closed
