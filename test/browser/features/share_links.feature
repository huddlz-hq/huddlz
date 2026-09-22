@clipboard_browser
Feature: Copy a page's address from its Share section
  Scenario Outline: Copying a <page> address with direct clipboard access <availability>
    Given I am viewing a public "<page>" to share
    And direct clipboard access is "<availability>"
    When I copy the address from the Share section
    Then my clipboard contains the page's address
    And the Share section confirms the address was copied

    Examples:
      | page  | availability |
      | huddl | available    |
      | huddl | unavailable  |
      | huddl | rejected     |
      | group | available    |
      | group | unavailable  |
      | group | rejected     |

  Scenario: Copying from the QR code dialog still works without direct clipboard access
    Given I am viewing a public "huddl" to share
    And direct clipboard access is "unavailable"
    When I copy the address from the QR code dialog
    Then my clipboard contains the page's address
    And the QR code dialog confirms the address was copied
