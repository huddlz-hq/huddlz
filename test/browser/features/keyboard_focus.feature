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

  Scenario Outline: A failed save puts keyboard focus on the first field to fix
    Given I open the "<form>" form in a browser
    When I save it with "<field>" left empty
    Then "<field>" has keyboard focus
    And "<field>" describes what is wrong with it

    Examples:
      | form              | field         |
      | sign in           | Email         |
      | registration      | Email         |
      | password reset    | Email         |
      | profile           | Display name  |
      | new group         | Group name    |
      | edit group        | Group Name    |
      | new huddl         | Title         |
      | edit huddl        | Title         |
      | address book      | Address       |

  Scenario: A save with nothing wrong leaves focus alone
    Given I open the "profile" form in a browser
    When I save it with "Display name" set to "Keyboard Person"
    Then "Save changes" still has keyboard focus
