@focus_browser
Feature: Keyboard focus past navigation and onto form errors
  As someone using a keyboard
  I want to skip the navigation and land on the field I need to fix
  So I don't have to Tab through the whole page to get there

  Scenario: The skip link moves past the navigation
    Given I am signed in and looking at my groups in a browser
    When I press Tab from the top of the page
    Then "Skip to main content" has keyboard focus
    When I follow the skip link with Enter
    Then keyboard focus is in the page content
    When I press Tab
    Then keyboard focus is still in the page content

  Scenario Outline: The skip link comes first on <page>
    Given I open "<page>" in a browser
    When I press Tab from the top of the page
    Then "Skip to main content" has keyboard focus
    When I follow the skip link with Enter
    Then keyboard focus is in the page content

    Examples:
      | page            |
      | the home page   |
      | sign in         |
      | discover        |
