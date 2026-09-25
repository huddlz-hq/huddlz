@focus_browser
Feature: Keyboard focus past navigation and onto form errors
  As someone using a keyboard
  I want to skip the navigation and land on the field I need to fix
  So I don't have to Tab through the whole page to get there

  @focus_landmark
  Scenario: The skip link moves past the navigation
    Given I am signed in and looking at my groups in a browser
    When I press Tab from the top of the page
    Then "Skip to main content" has keyboard focus
    When I follow the skip link with Enter
    Then keyboard focus is in the page content
    And the main content landmark has keyboard focus
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
      | invitation        | Email         |

  Scenario: A save with nothing wrong leaves focus alone
    Given I open the "profile" form in a browser
    When I save it with "Display name" set to "Keyboard Person"
    Then "Save changes" still has keyboard focus

  @focus_legal
  Scenario: Registration focuses the unchecked agreement
    Given I open the "registration" form in a browser
    When I register without accepting the terms
    Then the agreement has keyboard focus and describes what is wrong

  @focus_schedule
  Scenario: Finishing an invalid social schedule focuses its opening line
    Given I am editing a social connection as its owner
    When I finish with an opening line longer than 140 characters
    Then "Opening line" has keyboard focus
    And "Opening line" describes what is wrong with it

  @focus_address
  Scenario: Creating an address focuses the address that needs correcting
    Given I open the "new address" form in a browser
    When I save it with "Address" left empty
    Then "Address" has keyboard focus
    And "Address" describes what is wrong with it

  @focus_turnout
  Scenario: Recording turnout focuses the missing count
    Given I have opened the overview of a group with an uncounted past huddl
    When I try to record turnout without a count
    Then "People in the room" has keyboard focus
    And "People in the room" describes what is wrong with it

  @focus_group_location
  Scenario: Creating a group focuses its missing location
    Given I open the "new group" form in a browser
    When I save the new group without a location
    Then "Location" has keyboard focus
    And "Location" describes what is wrong with it

  @focus_group_location_edit
  Scenario: Editing a group focuses its cleared location
    Given I open the "edit group" form in a browser
    When I clear the group location and save
    Then "Location" has keyboard focus
    And "Location" describes what is wrong with it
